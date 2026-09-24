module SellerPortal
  class OrderMessagesController < BaseController
    rate_limit to: 10, within: 5.minutes, only: :create,
      with: -> { redirect_to seller_order_messages_path(params[:order_id]), alert: "Muitas mensagens em pouco tempo. Aguarde alguns minutos." }

    before_action :set_conversation, only: %i[show create]

    def index
      @seller_orders = current_seller.seller_orders
        .where(status: SellerOrder::MESSAGEABLE_STATUSES)
        .includes(:order_messages, order: :customer)
        .order(updated_at: :desc)
    end

    def show
      @message = @seller_order.order_messages.new
      @messages = @seller_order.order_messages.includes(:sender).chronological
    end

    def create
      @message = @seller_order.order_messages.new(message_params.merge(sender: Current.user))

      if @message.save
        NotifyOrderMessageJob.perform_later(@message)
        Notification.create!(
          recipient: @order.customer,
          kind: :new_message,
          title: "Nova mensagem do vendedor",
          body: "Você recebeu uma nova mensagem sobre o pedido ##{@order.id}.",
          url: order_path(@order)
        )
        redirect_to seller_order_messages_path(@order), notice: "Mensagem enviada ao cliente."
      else
        @messages = @seller_order.order_messages.includes(:sender).chronological
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_conversation
      @seller_order = current_seller.seller_orders
        .includes(order: :customer)
        .find_by!(order_id: params[:order_id])
      @order = @seller_order.order
      return if @seller_order.accepts_messages?

      redirect_to seller_messages_path, alert: "As mensagens ficam disponíveis depois da confirmação do pagamento."
    end

    def message_params
      params.expect(order_message: [ :body ])
    end
  end
end
