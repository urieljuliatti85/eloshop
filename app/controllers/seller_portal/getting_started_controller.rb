module SellerPortal
  class GettingStartedController < BaseController
    # A ordem é a da `Seller#getting_started_steps`; a chave é o pedaço da URL.
    STEP_SLUGS = {
      address: "endereco",
      mercado_pago: "mercado-pago",
      pix_key: "chave-pix",
      superfrete: "superfrete",
      product: "primeira-peca",
      approval: "aprovacao"
    }.freeze

    # Título de cada etapa aberta (aqui e no painel inicial).
    STEP_TITLES = {
      address: "Preencha o endereço do ateliê",
      mercado_pago: "Conecte sua conta do Mercado Pago",
      pix_key: "Cadastre uma chave PIX no Mercado Pago",
      superfrete: "Conecte sua conta da SuperFrete",
      product: "Cadastre seu primeiro produto",
      approval: "Entenda como você recebe"
    }.freeze

    # Nome curto de cada etapa na faixa (aqui e no painel inicial).
    STEP_SHORT_TITLES = {
      address: "Endereço do ateliê",
      mercado_pago: "Conta do Mercado Pago",
      pix_key: "Chave PIX",
      superfrete: "SuperFrete",
      product: "Primeira peça",
      approval: "Aprovação e recebimento"
    }.freeze

    def show
      @steps = current_seller.getting_started_steps
      @completed_steps_count = @steps.count { |_step, completed| completed }
      # Uma etapa que não vale neste ambiente (a SuperFrete com a cotação
      # desligada) cai na próxima pendente, como se não viesse na URL.
      requested = STEP_SLUGS.key(params[:etapa])
      @current_step = (requested if @steps.key?(requested)) || @steps.find { |_step, completed| !completed }&.first
      @next_pending_step = @steps.keys.drop(@steps.keys.index(@current_step).to_i + 1).find { |step| !@steps[step] } if @current_step

      set_mercado_pago_oauth_state
      set_superfrete_oauth_state
    end
  end
end
