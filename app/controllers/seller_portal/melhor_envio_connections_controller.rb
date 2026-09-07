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

    def valid_state?(received_state)
      stored_digest = session.delete(:melhor_envio_oauth_state_digest)
      stored_created_at = session.delete(:melhor_envio_oauth_created_at)
      return false if stored_digest.blank? || received_state.blank?
      return false if Time.zone.at(Integer(stored_created_at)) < OAUTH_STATE_TTL.ago

      received_digest = Digest::SHA256.hexdigest(received_state)
      ActiveSupport::SecurityUtils.secure_compare(stored_digest, received_digest)
    rescue ArgumentError, TypeError
      false
    end
  end
end
