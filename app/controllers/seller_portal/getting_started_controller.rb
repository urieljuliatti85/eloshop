module SellerPortal
  class GettingStartedController < BaseController
    def show
      @steps = current_seller.getting_started_steps
      @completed_steps_count = @steps.count { |_step, completed| completed }
      @progress_percentage = (@completed_steps_count.fdiv(@steps.size) * 100).round

      set_mercado_pago_oauth_state
    end
  end
end
