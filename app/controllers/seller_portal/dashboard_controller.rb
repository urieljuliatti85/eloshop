module SellerPortal
  class DashboardController < BaseController
    def index
      @products_count = current_seller.products.count
      @active_products_count = current_seller.products.active.count
      @low_stock_count = current_seller.products.low_stock.count
      mercado_pago_oauth = Marketplace::MercadoPagoOauth.new
      @mercado_pago_oauth_configured = mercado_pago_oauth.configured?
      @mercado_pago_oauth_sandbox = mercado_pago_oauth.sandbox?
    end
  end
end
