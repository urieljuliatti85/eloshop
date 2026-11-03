# Desistência ou problema pelo site, com protocolo e confirmação imediata
# (ADR 008, Fase 1; Decreto 7.962, art. 5º). Fora de `require_sales_open` de
# propósito: desistir é direito do comprador mesmo com as vendas fechadas.
# Todo acesso parte de `Current.customer` — o comprador nunca alcança o
# pedido ou a solicitação de outro trocando um id na URL.
class ReturnRequestsController < StorefrontController
  account_area

  rate_limit to: 10, within: 10.minutes, only: :create,
    with: -> { redirect_to order_path(params[:order_id]), alert: "Muitas tentativas. Tente novamente em alguns minutos." }
  rate_limit to: 5, within: 1.hour, only: :create, by: -> { Current.customer.id }, name: "per-customer",
    with: -> { redirect_to order_path(params[:order_id]), alert: "Muitas tentativas. Tente novamente em alguns minutos." }

  before_action :set_order

  def new
    unless ReturnRequest.eligible?(@seller_order)
      redirect_to order_path(@order), alert: "Este pedido não aceita solicitações pelo site. Fale com contato@eloshop.shop."
      return
    end

    @available_kinds = ReturnRequest.available_kinds(@seller_order)
    if @available_kinds.empty?
      open_request = @seller_order.return_requests.open.order(:created_at).first
      redirect_to order_return_request_path(@order, open_request),
        notice: "Você já tem uma solicitação aberta neste pedido. Acompanhe por aqui ou responda o e-mail do protocolo."
      return
    end

    @return_request = @seller_order.return_requests.new(kind: params[:kind])
  end

  def create
    result = ReturnRequests::Open.new(
      seller_order: @seller_order,
      customer: Current.customer,
      kind: return_request_params[:kind],
      description: return_request_params[:description]
    ).call

    notice = if result.created
      "Solicitação registrada. Seu protocolo é #{result.return_request.protocol}."
    else
      "Você já tinha uma solicitação deste tipo aberta (#{result.return_request.protocol}); acrescentamos a sua mensagem a ela."
    end
    redirect_to order_return_request_path(@order, result.return_request), notice: notice
  rescue ReturnRequests::Open::NotEligible => e
    @available_kinds = ReturnRequest.available_kinds(@seller_order).presence || ReturnRequest.kinds.keys
    @return_request = @seller_order.return_requests.new(return_request_params.slice(:kind, :description))
    flash.now[:alert] = e.message.upcase_first
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    @available_kinds = ReturnRequest.available_kinds(@seller_order).presence || ReturnRequest.kinds.keys
    @return_request = @seller_order.return_requests.new(return_request_params.slice(:kind, :description))
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  def show
    @return_request = @seller_order.return_requests.find(params[:id])
    @updates = @return_request.updates.chronological.includes(:author)
  end

  private

  def set_order
    @order = Current.customer.orders.find(params[:order_id])
    @seller_order = @order.seller_order
  end

  def return_request_params
    params.fetch(:return_request, {}).permit(:kind, :description)
  end
end
