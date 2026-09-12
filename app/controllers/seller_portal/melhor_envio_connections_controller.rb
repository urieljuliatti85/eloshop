module SellerPortal
  class MelhorEnvioConnectionsController < BaseController
    OAUTH_STATE_TTL = 10.minutes

    def create
      state = SecureRandom.urlsafe_base64(32)
      session[:melhor_envio_oauth_state_digest] = Digest::SHA256.hexdigest(state)
      session[:melhor_envio_oauth_created_at] = Time.current.to_i

      redirect_to oauth.authorization_url(state: state), allow_other_host: true
    rescue Marketplace::MelhorEnvioOauth::ConfigurationError => e
      session.delete(:melhor_envio_oauth_state_digest)
      session.delete(:melhor_envio_oauth_created_at)
      redirect_to seller_atelier_path, alert: e.message
    end

    def callback
      unless valid_state?(params[:state]) && params[:code].present?
        redirect_to seller_atelier_path, alert: "Não foi possível validar o retorno do Melhor Envio. Tente novamente."
        return
      end

      current_seller.connect_melhor_envio!(oauth.exchange(code: params[:code]), sandbox: oauth.sandbox?)
      redirect_to seller_atelier_path, notice: "Conta Melhor Envio conectada. O frete real passa a ser cotado nos seus pedidos."
    rescue Marketplace::MelhorEnvioOauth::ConfigurationError,
      Marketplace::MelhorEnvioOauth::RequestFailed => e
      redirect_to seller_atelier_path, alert: e.message
    end

    def destroy
      current_seller.disconnect_melhor_envio!
      redirect_to seller_atelier_path, notice: "Conta Melhor Envio desconectada. O frete volta a usar a tabela padrão."
    end

    private

    def oauth
      @oauth ||= Marketplace::MelhorEnvioOauth.new
    end

    # TEMPORÁRIO (2026-09-12): a conexão falha em produção sem gravar nada e
    # sem alerta visível — o guard recusa, mas não dizia por quê, e as quatro
    # causas possíveis (sessão perdida no retorno cross-site, TTL, state
    # divergente, created_at ausente) pedem correções diferentes. Loga só a
    # PRESENÇA de cada chave e o motivo; nunca o state nem o digest, que são
    # segredo de sessão (§43). Remover junto com a correção da causa.
    def valid_state?(received_state)
      stored_digest = session.delete(:melhor_envio_oauth_state_digest)
      stored_created_at = session.delete(:melhor_envio_oauth_created_at)

      reason = state_rejection_reason(stored_digest, stored_created_at, received_state)
      if reason
        log_state_rejection(reason, stored_digest, stored_created_at, received_state)
        return false
      end

      true
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

      received_digest = Digest::SHA256.hexdigest(received_state)
      return "digest_mismatch" unless ActiveSupport::SecurityUtils.secure_compare(stored_digest, received_digest)

      nil
    end

    def log_state_rejection(reason, stored_digest, stored_created_at, received_state)
      Rails.event.notify(
        "marketplace.melhor_envio_oauth.state_rejected",
        reason: reason,
        stored_digest_present: stored_digest.present?,
        created_at_present: stored_created_at.present?,
        received_state_present: received_state.present?,
        session_id_present: session.id.present?,
        seller_id: current_seller&.id
      )
    rescue StandardError
      nil
    end
  end
end
