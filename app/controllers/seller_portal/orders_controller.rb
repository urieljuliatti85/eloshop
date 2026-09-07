module SellerPortal
  class OrdersController < BaseController
    def index
      @seller_orders = current_seller.seller_orders.includes(order: :customer).order(created_at: :desc)
    end

    def show
      @seller_order = current_seller.seller_orders
        .includes(:shipment, order: :customer, order_items: :product)
        .find_by!(order_id: params[:id])
      @order = @seller_order.order
      @order_items = @seller_order.order_items
    end

    def cancel
      order = current_seller.seller_orders.find_by!(order_id: params[:id]).order
      Orders::Cancel.new.call(order)

      redirect_to seller_order_path(order), notice: "Pedido cancelado e estoque devolvido."
    rescue Orders::Cancel::InvalidCancellation => e
      redirect_to seller_order_path(order), alert: e.message
    end
  end
end
