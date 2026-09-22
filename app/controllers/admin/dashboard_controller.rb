module Admin
  class DashboardController < BaseController
    RECENT_LIMIT = 10

    def index
      @pending_orders = Order.pending.includes(:customer, :payments).order(created_at: :desc).limit(RECENT_LIMIT)
      @pending_orders_count = Order.pending.count

      @low_stock_products = Product.low_stock.order(:stock_quantity).to_a
      @low_stock_variants = ProductVariant.low_stock.includes(:product).order(:stock_quantity).to_a
      @low_stock_items = (@low_stock_products + @low_stock_variants).sort_by(&:stock_quantity)

      @sold_out_products = Product.sold_out.without_variants.order(:name).to_a
      @sold_out_variants = ProductVariant.out_of_stock.includes(:product).order("products.name", :sku).to_a
      @sold_out_items = @sold_out_products + @sold_out_variants

      @pending_reviews = Review.pending.includes(:product, :customer).order(created_at: :desc).limit(RECENT_LIMIT)
      @pending_reviews_count = Review.pending.count

      @platform_fee_cents = SellerOrder.joins(:order)
        .where(orders: { status: %w[confirmed partially_refunded refunded] })
        .sum("platform_fee_cents - platform_fee_refunded_cents")

      @funnel_snapshot = ::Analytics::FunnelReport.new.snapshot
      load_google_analytics
    end

    private

    def load_google_analytics
      report = ::Analytics::GoogleAnalyticsReport.new
      @analytics_configured = report.configured?
      @analytics_snapshot = report.snapshot if @analytics_configured
    rescue ::Analytics::GoogleAnalyticsReport::ReportUnavailable
      @analytics_unavailable = true
    end
  end
end
