module Admin
  class OrdersController < BaseController
    def index
      @orders = Order.includes(:customer, :payments).order(created_at: :desc)
      @order_counts = Order.group(:status).count
    end

    def show
      @order = Order.includes(:customer, :coupon, :payments, :shipment,
        order_items: { product: :main_image_attachment }).find(params[:id])
    end
  end
end
