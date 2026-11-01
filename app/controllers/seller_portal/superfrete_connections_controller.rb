module SellerPortal
  # Conexão do ateliê com a SuperFrete (ADR 005). Tudo parte de
  # `current_seller`: nenhuma ação aceita id de vendedor por parâmetro.
  class SuperfreteConnectionsController < BaseController
    OAUTH_STATE_TTL = 10.minutes

    # Com as cotações externas desligadas no ambiente, conectar não teria
    # efeito — e em produção gravaria tokens de um app de sandbox.
    before_action :require_remote_quotes_enabled, only: %i[create callback]

    def create
      redirect_to oauth.authorization_url(state: issue_state), allow_other_host: true
    rescue Marketplace::SuperfreteOauth::ConfigurationError => e
      discard_state
      redirect_to seller_atelier_path, alert: e.message
    end

    # A troca do código e a leitura da conta acontecem antes de gravar: se
    # qualquer uma falhar, a conexão anterior (se houver) continua intacta.
    def callback
      unless valid_state?(params[:state]) && params[:code].present?
        redirect_to seller_atelier_path, alert: "Não foi possível validar o retorno da SuperFrete. Tente novamente."
        return
      end

      access_token = oauth.exchange(code: params[:code])
      account = oauth.account(access_token: access_token)
      previous_account_id = current_seller.superfrete_account_id
      current_seller.connect_superfrete!(access_token: access_token, account: account, sandbox: oauth.sandbox?)

      redirect_to seller_atelier_path, notice: connected_notice(account, previous_account_id)
    rescue Marketplace::SuperfreteOauth::ConfigurationError,
      Marketplace::SuperfreteOauth::RequestFailed => e
      redirect_to seller_atelier_path, alert: e.message
    end

    def destroy
      current_seller.disconnect_superfrete!
      redirect_to seller_atelier_path, notice: "Conta SuperFrete desconectada na EloShop. Para encerrar o acesso por completo, remova também a integração no painel da SuperFrete."
    end

    private

    # Quem paga as etiquetas é a carteira da conta conectada: trocar de conta
    # sem perceber mudaria quem paga. O aviso diz qual ficou.
    def connected_notice(account, previous_account_id)
      who = account.email.presence || "a conta #{account.id}"
      if previous_account_id.present? && previous_account_id != account.id
        "Conta SuperFrete trocada: agora é #{who}. As etiquetas passam a ser pagas por essa conta."
      else
        "Conta SuperFrete conectada: #{who}."
      end
    end

    def require_remote_quotes_enabled
      return if Shipping::Providers.enabled?

      redirect_to seller_atelier_path, alert: "A conexão com a SuperFrete está indisponível no momento. O frete dos seus produtos segue o valor que você definiu."
    end

    def oauth
      @oauth ||= Marketplace::SuperfreteOauth.new
    end

    # `state` do OAuth: um valor imprevisível vai para a SuperFrete, só o
    # digest fica na sessão, e o retorno é aceito uma vez, dentro do prazo,
    # com comparação em tempo constante — sem ele, um terceiro poderia forçar
    # a vinculação de uma conta (e de uma carteira) que não é do ateliê.
    def issue_state
      state = SecureRandom.urlsafe_base64(32)
      session[:superfrete_oauth_state_digest] = Digest::SHA256.hexdigest(state)
      session[:superfrete_oauth_created_at] = Time.current.to_i
      state
    end

    def discard_state
      session.delete(:superfrete_oauth_state_digest)
      session.delete(:superfrete_oauth_created_at)
    end

    def valid_state?(received_state)
      stored_digest = session.delete(:superfrete_oauth_state_digest)
      stored_created_at = session.delete(:superfrete_oauth_created_at)

      reason = state_rejection_reason(stored_digest, stored_created_at, received_state)
      return true unless reason

      report_state_rejection(reason, stored_digest, stored_created_at, received_state)
      false
    end

    def state_rejection_reason(stored_digest, stored_created_at, received_state)
      return "stored_digest_missing" if stored_digest.blank?
      return "received_state_missing" if received_state.blank?
      return "created_at_missing" if stored_created_at.blank?

      begin
        return "state_expired" if Time.zone.at(Integer(stored_created_at)) < OAUTH_STATE_TTL.ago
      rescue ArgumentError, TypeError
        return "created_at_unparseable"
      end

      received_digest = Digest::SHA256.hexdigest(received_state.to_s)
      return "digest_mismatch" unless ActiveSupport::SecurityUtils.secure_compare(stored_digest, received_digest)

      nil
    end

    # Só a PRESENÇA de cada peça e o motivo — nunca o state nem o digest, que
    # são segredo de sessão (§43).
    def report_state_rejection(reason, stored_digest, stored_created_at, received_state)
      Rails.event.notify(
        "marketplace.superfrete_oauth.state_rejected",
        reason: reason,
        stored_digest_present: stored_digest.present?,
        created_at_present: stored_created_at.present?,
        received_state_present: received_state.present?,
        seller_id: current_seller&.id
      )
    rescue StandardError
      nil
    end
  end
end
