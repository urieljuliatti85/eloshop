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

    # Título de cada etapa aberta (aqui e no painel inicial).
    STEP_TITLES = {
      address: "Preencha o endereço do ateliê",
      mercado_pago: "Conecte sua conta do Mercado Pago",
      pix_key: "Cadastre uma chave PIX no Mercado Pago",
      product: "Cadastre seu primeiro produto",
      approval: "Entenda como você recebe"
    }.freeze

    # Nome curto de cada etapa na faixa (aqui e no painel inicial).
    STEP_SHORT_TITLES = {
      address: "Endereço do ateliê",
      mercado_pago: "Conta do Mercado Pago",
      pix_key: "Chave PIX",
      product: "Primeira peça",
      approval: "Aprovação e recebimento"
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
