module Admin
  # Fila das solicitações pós-venda (ADR 008, Fase 1): prazo de 2 dias úteis,
  # resposta ao comprador e mudança de status. O reembolso continua na tela do
  # pedido (Payments::Refund) e o estoque no cadastro do produto — a Fase 1 não
  # liga a solicitação ao reembolso.
  class ReturnRequestsController < BaseController
    FILTERS = {
      "open" => ->(scope) { scope.open },
      "overdue" => ->(scope) { scope.open.where(respond_by: ...Time.zone.today) },
      "done" => ->(scope) { scope.where(status: %w[resolved closed]) },
      "all" => ->(scope) { scope }
    }.freeze

    def index
      @filter = FILTERS.key?(params[:filter]) ? params[:filter] : "open"
      @open_count = ReturnRequest.open.count
      @overdue_count = ReturnRequest.open.where(respond_by: ...Time.zone.today).count

      return_requests = ReturnRequest.preload(seller_order: [ :seller, { order: :customer } ])
      return_requests = FILTERS.fetch(@filter).call(return_requests)
      return_requests = @filter == "done" ? return_requests.order(resolved_at: :desc, id: :desc) : return_requests.by_deadline
      @return_requests = paginate(return_requests)
    end

    def show
      @return_request = ReturnRequest.find(params[:id])
      @order = @return_request.order
      @seller_order = @return_request.seller_order
      @updates = @return_request.updates.chronological.includes(:author)
      @items = @return_request.items.includes(:order_item)
      @payments = @order.payments.includes(:payment_refunds).order(:created_at)
    end

    def update
      return_request = ReturnRequest.find(params[:id])
      update = return_request.record_update!(
        author: Current.user,
        body: update_params[:body],
        new_status: update_params[:status]
      )

      if update
        ReturnRequests::Notifications.updated(update)
        redirect_to admin_return_request_path(return_request), notice: "Solicitação atualizada. Comprador, ateliê e demais admins foram avisados."
      else
        redirect_to admin_return_request_path(return_request), alert: "Escreva uma resposta ou escolha uma nova situação."
      end
    rescue ReturnRequest::InvalidStatusTransition, ActiveRecord::RecordInvalid => e
      redirect_to admin_return_request_path(params[:id]), alert: e.message.upcase_first
    end

    private

    def update_params
      params.fetch(:return_request_update, {}).permit(:body, :status)
    end
  end
end
