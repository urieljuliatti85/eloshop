module Gateways
  # Resultado de uma tentativa de cobrança, no vocabulário do domínio e não no
  # de um fornecedor.
  #
  # `external_id` é o mínimo que qualquer gateway devolve. Os campos de PIX são
  # opcionais porque nem todo meio de pagamento tem QR code — um gateway de
  # cartão preencheria só o id. Estão aqui, e não num adapter específico,
  # porque "QR code do PIX" é conceito do meio de pagamento brasileiro, não do
  # Mercado Pago: outro provedor de PIX preencheria os mesmos campos.
  #
  # `status` é o desfecho imediato da autorização, no vocabulário de
  # Gateways::MercadoPago::STATUS_MAP ("approved"/"pending"/"declined"). PIX
  # sempre nasce "pending" (aguarda o webhook); cartão de crédito aprova ou
  # recusa na própria resposta HTTP, sem passar por webhook.
  Intent = Data.define(
    :external_id, :status, :qr_code, :qr_code_base64, :expires_at,
    :card_last_four, :card_brand
  ) do
    def initialize(external_id:, status: "pending", qr_code: nil, qr_code_base64: nil, expires_at: nil,
                   card_last_four: nil, card_brand: nil)
      super
    end

    def pix?
      qr_code.present?
    end
  end
end
