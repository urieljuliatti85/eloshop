module ShippingLabels
  # Webhook de rastreio na conta SuperFrete do ateliê (ADR 005). Respostas da
  # SuperFrete em 2026-11-11: o token OAuth de cada ateliê registra o webhook
  # na conta dele, e não existe webhook único do app — cada conta tem o seu,
  # com o seu `secret_token`. A URL leva um identificador aleatório do ateliê
  # (`superfrete_webhook_key`) para achar o segredo antes de verificar a
  # assinatura.
  #
  # Registrar cria o novo antes de apagar o antigo: não há janela sem webhook,
  # e uma falha ao apagar deixa no máximo um webhook sobrando, cujas
  # notificações chegam com a chave antiga e são recusadas.
  class Webhook
    EVENTS = %w[order.released order.generated order.posted order.delivered order.cancelled].freeze
    NAME = "EloShop — rastreio".freeze

    def initialize(seller, client: nil, interactive: false)
      @seller = seller
      @client = client || ShippingLabels.client_for(seller, interactive: interactive)
    end

    # Só com a etiqueta ligada: é ela que cria o que rastrear.
    def register
      return false unless ShippingLabels.enabled? && @seller.superfrete_ready?

      key = SecureRandom.urlsafe_base64(24)
      created = @client.create_webhook(name: NAME, url: url_for(key), events: EVENTS)
      previous_id = @seller.superfrete_webhook_id
      @seller.store_superfrete_webhook!(id: created.fetch(:id), key: key, secret: created.fetch(:secret))
      delete_quietly(previous_id) if previous_id.present? && previous_id != created.fetch(:id)
      Rails.event.notify("shipping.webhook_registered", seller_id: @seller.id)
      true
    end

    # Antes de desconectar, enquanto o token ainda existe. Falhar aqui não
    # impede a desconexão: sem a chave, as notificações são recusadas.
    def unregister
      delete_quietly(@seller.superfrete_webhook_id) if @seller.superfrete_webhook_id.present?
    end

    private

    def delete_quietly(webhook_id)
      @client.delete_webhook(webhook_id)
    rescue Client::Error => e
      Rails.event.notify("shipping.webhook_delete_failed", seller_id: @seller.id, error: e.class.name.demodulize)
      nil
    end

    def url_for(key)
      Rails.application.routes.url_helpers.superfrete_webhook_url(key, **Rails.application.config.action_mailer.default_url_options.to_h)
    end
  end
end
