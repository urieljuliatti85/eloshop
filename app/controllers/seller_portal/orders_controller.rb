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
  end
end
