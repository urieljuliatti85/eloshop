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
        notify(return_request, update)
        redirect_to admin_return_request_path(return_request), notice: "Solicitação atualizada. O comprador foi avisado por e-mail."
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

    # Fora da transação de record_update!, e cada aviso por conta própria (ver
    # ReturnRequests.deliver_safely): o atendimento já está gravado.
    def notify(return_request, update)
      order = return_request.order

      ReturnRequests.deliver_safely(return_request) { ReturnRequestMailer.updated(update).deliver_later }
      ReturnRequests.deliver_safely(return_request) do
        Notification.create!(
          recipient: order.customer,
          kind: :return_request_updated,
          title: "Solicitação #{return_request.protocol} atualizada",
          body: update.status_change? ? "Situação: #{return_request.status_label}." : "A EloShop respondeu à sua solicitação.",
          url: order_return_request_path(order, return_request)
        )
      end
      return unless update.status_change? && !return_request.open?

      # O fim de uma desistência destrava o envio no painel (decisão A).
      ReturnRequests.deliver_safely(return_request) do
        Notification.create!(
          recipient: return_request.seller_order.seller,
          kind: :return_request_updated,
          title: "Solicitação #{return_request.protocol} #{return_request.status_label.downcase}",
          body: "A EloShop encerrou a solicitação do pedido ##{order.id} (#{return_request.kind_label.downcase}).",
          url: seller_order_path(order)
        )
      end
    end
  end
end
