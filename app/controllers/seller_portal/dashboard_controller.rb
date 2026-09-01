module SellerPortal
  class DashboardController < BaseController
    def index
      @products_count = current_seller.products.count
      @active_products_count = current_seller.products.active.count
      @low_stock_count = current_seller.products.low_stock.count
    end
  end
end
