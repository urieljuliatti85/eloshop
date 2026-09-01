module Marketplace
  class MercadoPagoAccessToken
    RENEWAL_WINDOW = 5.minutes

    def initialize(seller:, oauth: MercadoPagoOauth.new)
      @seller = seller
      @oauth = oauth
    end

    def call
      @seller.with_lock do
        raise MercadoPagoOauth::ConfigurationError, "a conta Mercado Pago do artesão não está conectada" unless @seller.mercado_pago_connected?

        return @seller.mercado_pago_access_token unless expiring?

        credentials = @oauth.refresh(refresh_token: @seller.mercado_pago_refresh_token)
        unless credentials.user_id == @seller.mercado_pago_user_id
          raise MercadoPagoOauth::RequestFailed, "Mercado Pago devolveu uma conta diferente na renovação"
        end

        @seller.connect_mercado_pago!(credentials)
        credentials.access_token
      end
    end

    private

    def expiring?
      @seller.mercado_pago_token_expires_at.blank? ||
        @seller.mercado_pago_token_expires_at <= RENEWAL_WINDOW.from_now
    end
  end
end
