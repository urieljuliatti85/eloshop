# Etiqueta da SuperFrete comprada pelo ateliê (ADR 005, "Etapa 2 e 3").
module ShippingLabels
  # Recusa explicada ao ateliê: a mensagem vai para a tela.
  class Refused < StandardError; end

  # Chave por ambiente (`config.x.shipping.labels_enabled`). Em produção nasce
  # desligada até a validação com saldo real (SHIPPING_LABELS_ENABLED).
  def self.enabled?
    Rails.configuration.x.shipping.labels_enabled == true
  end

  # `interactive: true` para chamadas feitas durante a requisição do painel.
  def self.client_for(seller, interactive: false)
    Client.new(seller: seller, read_timeout: interactive ? Client::INTERACTIVE_READ_TIMEOUT : Client::READ_TIMEOUT)
  end
end
