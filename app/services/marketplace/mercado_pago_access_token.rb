module Marketplace
  class MercadoPagoAccessToken
    RENEWAL_WINDOW = 5.minutes

    # `for_charge: true` (padrão) é para COBRAR: exige conexão ativa e ateliê
    # não suspenso — o gateway não confere o status do ateliê, então é aqui que
    # a cobrança de quem desconectou ou foi suspenso é barrada. `false` serve
    # para estornar e consultar pagamentos já feitos, e aceita o token que
    # ficou guardado depois de desconectar ou suspender (ver Seller#suspend!).
    def initialize(seller:, oauth: MercadoPagoOauth.new, for_charge: true)
      @seller = seller
      @oauth = oauth
      @for_charge = for_charge
    end

    def call
      @seller.with_lock do
        ensure_usable!

        return @seller.mercado_pago_access_token unless expiring?

        credentials = @oauth.refresh(refresh_token: @seller.mercado_pago_refresh_token)
        unless credentials.user_id == @seller.mercado_pago_user_id
          raise MercadoPagoOauth::RequestFailed, "Mercado Pago devolveu uma conta diferente na renovação"
        end

        @seller.renew_mercado_pago_tokens!(credentials)
        credentials.access_token
      end
    end

    private

    def ensure_usable!
      if @for_charge
        raise MercadoPagoOauth::ConfigurationError, "a conta Mercado Pago do artesão não está conectada" unless @seller.mercado_pago_connected?
        raise MercadoPagoOauth::ConfigurationError, "o ateliê está suspenso e não pode receber cobranças" if @seller.suspended?
      else
        raise MercadoPagoOauth::ConfigurationError, "não há credencial do Mercado Pago guardada para este ateliê" unless @seller.mercado_pago_refund_credentials?
      end
    end

    def expiring?
      @seller.mercado_pago_token_expires_at.blank? ||
        @seller.mercado_pago_token_expires_at <= RENEWAL_WINDOW.from_now
    end
  end
end
