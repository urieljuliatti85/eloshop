require "digest"

module SellerPortal
  class MercadoPagoConnectionsController < BaseController
    OAUTH_STATE_TTL = 10.minutes

    def create
      state = SecureRandom.urlsafe_base64(32)
      code_verifier = SecureRandom.urlsafe_base64(64)
      session[:mercado_pago_oauth] = {
        "state_digest" => Digest::SHA256.hexdigest(state),
        "code_verifier" => code_verifier,
        "created_at" => Time.current.to_i
      }

      redirect_to oauth.authorization_url(state: state, code_challenge: code_challenge_for(code_verifier)),
        allow_other_host: true
    rescue Marketplace::MercadoPagoOauth::ConfigurationError => e
      session.delete(:mercado_pago_oauth)
      redirect_to seller_atelier_path, alert: e.message
    end

    def callback
      code_verifier = valid_state_and_code_verifier(params[:state])
      unless code_verifier && params[:code].present?
        redirect_to seller_atelier_path, alert: "Não foi possível validar o retorno do Mercado Pago. Tente novamente."
        return
      end

      current_seller.connect_mercado_pago!(oauth.exchange(code: params[:code], code_verifier: code_verifier))
      redirect_to seller_atelier_path, notice: "Conta Mercado Pago conectada. A plataforma agora pode concluir a aprovação."
    rescue Marketplace::MercadoPagoOauth::ConfigurationError,
      Marketplace::MercadoPagoOauth::RequestFailed => e
      redirect_to seller_atelier_path, alert: e.message
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to seller_atelier_path, alert: "Esta conta Mercado Pago já está vinculada ou não pôde ser salva."
    end

    def destroy
      current_seller.disconnect_mercado_pago!
      redirect_to seller_atelier_path, notice: "Conta Mercado Pago desconectada. A publicação foi suspensa até uma nova aprovação."
    end

    private

    def oauth
      @oauth ||= Marketplace::MercadoPagoOauth.new
    end

    def code_challenge_for(code_verifier)
      Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
    end

    def valid_state_and_code_verifier(received_state)
      stored = session.delete(:mercado_pago_oauth)
      return nil if stored.blank? || received_state.blank?
      return nil if Time.zone.at(Integer(stored["created_at"])) < OAUTH_STATE_TTL.ago

      received_digest = Digest::SHA256.hexdigest(received_state)
      return nil unless ActiveSupport::SecurityUtils.secure_compare(stored["state_digest"], received_digest)

      stored["code_verifier"]
    rescue ArgumentError, TypeError
      nil
    end
  end
end
