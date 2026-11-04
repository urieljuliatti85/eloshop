module SellerPortal
  # Conexão do ateliê com a SuperFrete (ADR 005). `create` e `destroy` partem
  # de `current_seller`: nenhuma ação aceita id de vendedor por parâmetro.
  #
  # O retorno (`callback`) é diferente: a SuperFrete entrega o `code` com um
  # GET feito pelo servidor dela, não pelo navegador do ateliê (observado em
  # produção em 2026-11-04: `axios`, IP do Google Cloud). Ele chega sem
  # sessão, então é público, e quem diz de qual ateliê é a autorização é o
  # `state` gravado em `create` (Seller#issue_superfrete_oauth_state!).
  class SuperfreteConnectionsController < BaseController
    allow_unauthenticated_access only: :callback
    skip_before_action :require_seller!, :require_current_terms!, only: :callback
    rate_limit to: 20, within: 1.minute, only: :callback, with: -> { head :too_many_requests }

    # Com as cotações externas desligadas no ambiente, conectar não teria
    # efeito — e em produção gravaria tokens de um app de sandbox.
    before_action :require_remote_quotes_enabled, only: :create

    def create
      redirect_to oauth.authorization_url(state: current_seller.issue_superfrete_oauth_state!), allow_other_host: true
    rescue Marketplace::SuperfreteOauth::ConfigurationError => e
      current_seller.discard_superfrete_oauth_state!
      redirect_to seller_atelier_path, alert: e.message
    end

    # A troca do código e a leitura da conta acontecem antes de gravar: se
    # qualquer uma falhar, a conexão anterior (se houver) continua intacta.
    # Responde 200 no sucesso — é o que a SuperFrete espera —, com uma página
    # que também serve a um navegador que chegue aqui.
    def callback
      return render_callback(:service_unavailable, "A conexão com a SuperFrete está indisponível no momento.") unless Shipping::Providers.enabled?

      seller, reason = params[:code].present? ? Seller.claim_superfrete_oauth_state(params[:state]) : [ nil, "code_missing" ]
      unless seller
        report_state_rejection(reason)
        return render_callback(:bad_request, "Não foi possível validar o retorno da SuperFrete. Volte ao painel e tente conectar de novo.")
      end

      access_token = oauth.exchange(code: params[:code], state: params[:state])
      account = oauth.account(access_token: access_token)
      previous_account_id = seller.superfrete_account_id
      seller.connect_superfrete!(access_token: access_token, account: account, sandbox: oauth.sandbox?)

      Rails.event.notify("marketplace.superfrete_oauth.connected", seller_id: seller.id,
        account_changed: previous_account_id.present? && previous_account_id != account.id)
      render_callback(:ok, connected_message(account, previous_account_id))
    rescue Marketplace::SuperfreteOauth::ConfigurationError,
      Marketplace::SuperfreteOauth::RequestFailed => e
      Rails.event.notify("marketplace.superfrete_oauth.failed", seller_id: seller&.id, reason: e.class.name.demodulize)
      render_callback(:bad_gateway, e.message)
    end

    def destroy
      current_seller.disconnect_superfrete!
      redirect_to seller_atelier_path, notice: "Conta SuperFrete desconectada na EloShop. Para encerrar o acesso por completo, remova também a integração no painel da SuperFrete."
    end

    private

    # Quem paga as etiquetas é a carteira da conta conectada: trocar de conta
    # sem perceber mudaria quem paga. A mensagem diz qual ficou.
    def connected_message(account, previous_account_id)
      who = account.email.presence || "a conta #{account.id}"
      if previous_account_id.present? && previous_account_id != account.id
        "Conta SuperFrete trocada: agora é #{who}. As etiquetas passam a ser pagas por essa conta."
      else
        "Conta SuperFrete conectada: #{who}."
      end
    end

    def render_callback(status, message)
      @message = message
      @success = status == :ok
      render :callback, layout: false, status: status
    end

    def require_remote_quotes_enabled
      return if Shipping::Providers.enabled?

      redirect_to seller_atelier_path, alert: "A conexão com a SuperFrete está indisponível no momento. O frete dos seus produtos segue o valor que você definiu."
    end

    def oauth
      @oauth ||= Marketplace::SuperfreteOauth.new
    end

    # Só o motivo — nunca o state, o digest ou o code (§43).
    def report_state_rejection(reason)
      Rails.event.notify("marketplace.superfrete_oauth.state_rejected", reason: reason)
    rescue StandardError
      nil
    end
  end
end
