module SellerPortal
  class GettingStartedController < BaseController
    def show
      @steps = {
        address: current_seller.origin_address_complete?,
        mercado_pago: current_seller.mercado_pago_connected?,
        product: current_seller.products.exists?,
        approval: current_seller.approved?
      }
      @completed_steps_count = @steps.count { |_step, completed| completed }
      @progress_percentage = (@completed_steps_count.fdiv(@steps.size) * 100).round
      @platform_fee_percentage = SellerOrder::PLATFORM_FEE_RATE_BPS.fdiv(100)

      set_mercado_pago_oauth_state
    end
  end
end
