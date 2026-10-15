module SellerPortal
  class GettingStartedController < BaseController
    # A ordem é a da `Seller#getting_started_steps`; a chave é o pedaço da URL.
    STEP_SLUGS = {
      address: "endereco",
      mercado_pago: "mercado-pago",
      pix_key: "chave-pix",
      product: "primeira-peca",
      approval: "aprovacao"
    }.freeze

    def show
      @steps = current_seller.getting_started_steps
      @completed_steps_count = @steps.count { |_step, completed| completed }
      @current_step = STEP_SLUGS.key(params[:etapa]) || @steps.find { |_step, completed| !completed }&.first
      @next_pending_step = @steps.keys.drop(@steps.keys.index(@current_step).to_i + 1).find { |step| !@steps[step] } if @current_step

      set_mercado_pago_oauth_state
    end
  end
end
