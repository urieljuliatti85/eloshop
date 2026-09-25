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

      load_seller_and_revenue_overview

      @funnel_snapshot = ::Analytics::FunnelReport.new.snapshot
      load_google_analytics
    end

    private

    # SQL em vez de `Seller.all.to_a` + contagem em Ruby (evita carregar a
    # base inteira de vendedores em memória a cada visita ao dashboard — o
    # mesmo padrão já corrigido em Admin::SellersController#index). Não
    # cacheado de propósito: é uma tela operacional, e o admin espera ver o
    # reflexo imediato de aprovar/suspender um vendedor ou confirmar um
    # pedido — um teste chegou a pegar o próprio redirect do login
    # congelando um total "zero" no cache antes de qualquer pedido existir.
    def load_seller_and_revenue_overview
      @sellers_in_risk = Seller.approved.where.not(id: Seller.accepted_current_terms_ids).count
      @seller_terms_pending_count = Seller.where.not(id: Seller.accepted_current_terms_ids).count
      @suspended_sellers_count = Seller.suspended.count
      @platform_fee_cents = SellerOrder.joins(:order)
        .where(orders: { status: %w[confirmed partially_refunded refunded] })
        .sum("platform_fee_cents - platform_fee_refunded_cents")
    end

    def load_google_analytics
      report = ::Analytics::GoogleAnalyticsReport.new
      @analytics_configured = report.configured?
      @analytics_snapshot = report.snapshot if @analytics_configured
    rescue ::Analytics::GoogleAnalyticsReport::ReportUnavailable
      @analytics_unavailable = true
    end
  end
end
