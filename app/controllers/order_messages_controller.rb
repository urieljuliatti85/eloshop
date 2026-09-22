class OrderMessagesController < StorefrontController
  rate_limit to: 10, within: 5.minutes, only: :create,
    with: -> { redirect_to order_messages_path(params[:order_id]), alert: "Muitas mensagens em pouco tempo. Aguarde alguns minutos." }

  before_action :set_conversation

  def index
    @message = @seller_order.order_messages.new
    @messages = @seller_order.order_messages.includes(:sender).chronological
  end

  def create
    @message = @seller_order.order_messages.new(message_params.merge(sender: Current.customer))

    if @message.save
      NotifyOrderMessageJob.perform_later(@message)
      redirect_to order_messages_path(@order), notice: "Mensagem enviada ao ateliê."
    else
      @messages = @seller_order.order_messages.includes(:sender).chronological
      render :index, status: :unprocessable_entity
    end
  end

  private

  def set_conversation
    @order = Current.customer.orders.includes(seller_orders: :seller).find(params[:order_id])
    @seller_order = @order.seller_order
    return if @seller_order.accepts_messages?

    redirect_to order_path(@order), alert: "As mensagens ficam disponíveis depois da confirmação do pagamento."
  end

  def message_params
    params.expect(order_message: [ :body ])
  end
end
