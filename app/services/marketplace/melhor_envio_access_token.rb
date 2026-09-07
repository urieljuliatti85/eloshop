module Marketplace
  class MelhorEnvioAccessToken
    RENEWAL_WINDOW = 5.minutes

    def initialize(seller:, oauth: MelhorEnvioOauth.new)
      @seller = seller
      @oauth = oauth
    end

    def call
      @seller.with_lock do
        raise MelhorEnvioOauth::ConfigurationError, "a conta Melhor Envio do artesão não está conectada" unless @seller.melhor_envio_connected?

        return @seller.melhor_envio_access_token unless expiring?

        credentials = @oauth.refresh(refresh_token: @seller.melhor_envio_refresh_token)
        @seller.connect_melhor_envio!(credentials)
        credentials.access_token
      end
    end

    private

    def expiring?
      @seller.melhor_envio_token_expires_at.blank? ||
        @seller.melhor_envio_token_expires_at <= RENEWAL_WINDOW.from_now
    end
  end
end
