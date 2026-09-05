require "digest"

module SellerPortal
  class MercadoPagoConnectionsController < BaseController
    OAUTH_STATE_TTL = 10.minutes

    def create
      state = SecureRandom.urlsafe_base64(32)
      session[:mercado_pago_oauth] = {
        "state_digest" => Digest::SHA256.hexdigest(state),
        "created_at" => Time.current.to_i
      }

      redirect_to oauth.authorization_url(state: state), allow_other_host: true
    rescue Marketplace::MercadoPagoOauth::ConfigurationError => e
      session.delete(:mercado_pago_oauth)
      redirect_to seller_atelier_path, alert: e.message
    end

    def callback
      unless valid_state?(params[:state]) && params[:code].present?
        redirect_to seller_atelier_path, alert: "Não foi possível validar o retorno do Mercado Pago. Tente novamente."
        return
      end

      current_seller.connect_mercado_pago!(oauth.exchange(code: params[:code]))
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

    def valid_state?(received_state)
      stored = session.delete(:mercado_pago_oauth)
      return false if stored.blank? || received_state.blank?
      return false if Time.zone.at(Integer(stored["created_at"])) < OAUTH_STATE_TTL.ago

      received_digest = Digest::SHA256.hexdigest(received_state)
      ActiveSupport::SecurityUtils.secure_compare(stored["state_digest"], received_digest)
    rescue ArgumentError, TypeError
      false
    end
  end
end
