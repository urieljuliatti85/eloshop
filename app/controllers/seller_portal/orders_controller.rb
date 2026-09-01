module SellerPortal
  class OrdersController < BaseController
    def index
      @orders = seller_orders.includes(:customer).order(created_at: :desc)
    end

    def show
      @order = seller_orders.includes(:customer, :shipment, order_items: :product).find(params[:id])
      @order_items = @order.order_items.select { |item| item.product.seller_id == current_seller.id }
    end

    private

    def seller_orders
      Order.joins(order_items: :product).where(products: { seller_id: current_seller.id }).distinct
    end
  end
end
