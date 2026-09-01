module Admin
  class DashboardController < BaseController
    RECENT_LIMIT = 10

    def index
      @pending_orders = Order.pending.includes(:customer, :payments).order(created_at: :desc).limit(RECENT_LIMIT)
      @pending_orders_count = Order.pending.count

      @low_stock_products = Product.low_stock.order(:stock_quantity)
      @sold_out_products = Product.sold_out.order(:name)

      @pending_reviews = Review.pending.includes(:product, :customer).order(created_at: :desc).limit(RECENT_LIMIT)
      @pending_reviews_count = Review.pending.count
    end
  end
end
