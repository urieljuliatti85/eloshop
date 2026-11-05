# Destinatário válido para checkout com entrega (CPF exigido): ver
# Checkout::Recipient. Specs do destinatário montam o próprio.
module CheckoutHelpers
  CHECKOUT_RECIPIENT_PARAMS = { name: "Cliente Teste", cpf: "529.982.247-25" }.freeze

  def checkout_recipient
    Checkout::Recipient.new(**CHECKOUT_RECIPIENT_PARAMS)
  end

  def checkout_recipient_params
    CHECKOUT_RECIPIENT_PARAMS
  end
end
