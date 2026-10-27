module SellerPortal
  class DashboardController < BaseController
    def index
      products = current_seller.products
      seller_orders = current_seller.seller_orders

      @products_count = products.count
      @active_products_count = products.active.count
      @low_stock_count = products.low_stock.count + ProductVariant.low_stock.where(products: { seller_id: current_seller.id }).count
      @orders_count = seller_orders.count
      @awaiting_payment_count = seller_orders.pending.count
      @to_prepare_count = current_seller.seller_orders_to_prepare.count
      @seller_revenue_cents = seller_orders.sum(:seller_amount_cents) -
        seller_orders.sum(:refunded_amount_cents) + seller_orders.sum(:platform_fee_refunded_cents)
      @recent_products = products.with_attached_main_image.order(updated_at: :desc).limit(4)
      @recent_seller_orders = seller_orders.includes(order: :customer).order(created_at: :desc).limit(4)

      set_getting_started_block(params[:etapa])
    end
  end
end
