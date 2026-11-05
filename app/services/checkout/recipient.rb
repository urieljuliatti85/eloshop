module Checkout
  # Quem recebe o pedido, como o comprador informou no checkout. A etiqueta da
  # SuperFrete exige nome e CPF do destinatário (ADR 005, "Etapa 2 e 3"); o
  # CPF só é cobrado quando há entrega, porque a retirada no ateliê não gera
  # etiqueta (decisão do Uriel, 2026-11-05). Telefone é opcional: os serviços
  # dos Correios que oferecemos não exigem.
  #
  # Só valida e normaliza: quem grava é `Checkout::CreateOrder`, no `Order`,
  # que cifra o CPF.
  class Recipient
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :name, :string
    attribute :cpf, :string
    attribute :phone, :string

    NAME_MAX_LENGTH = 100

    validates :name, presence: { message: "Informe o nome de quem vai receber" },
      length: { maximum: NAME_MAX_LENGTH, message: "Use até #{NAME_MAX_LENGTH} caracteres no nome" }
    validates :cpf, presence: { message: "Informe o CPF de quem vai receber: a transportadora exige na etiqueta" }, on: :delivery
    validate :cpf_must_be_valid
    validate :phone_must_be_valid

    # Qualquer coisa que não seja o grupo de campos esperado (ausente, ou um
    # texto no lugar do hash) vira destinatário vazio, que a validação recusa.
    def self.from_params(params)
      return new unless params.is_a?(ActionController::Parameters)

      new(params.permit(:name, :cpf, :phone).to_h)
    end

    def name=(value)
      super(value.to_s.squish.presence)
    end

    def cpf=(value)
      super(Cpf.digits(value).presence)
    end

    # Só os dígitos; o "+55" de quem cola o número internacional sai.
    def phone=(value)
      digits = value.to_s.gsub(/\D/, "")
      digits = digits.delete_prefix("55") if digits.length > 11
      super(digits.presence)
    end

    # `delivery: false` é retirada no ateliê. CPF digitado num pedido de
    # retirada continua validado, mas não é exigido.
    def valid_for?(delivery:)
      valid?(delivery ? :delivery : nil)
    end

    private

    def cpf_must_be_valid
      return if cpf.blank? || Cpf.valid?(cpf)

      errors.add(:cpf, "CPF inválido: confira os 11 números")
    end

    # DDD + número, com ou sem o 9: 10 ou 11 dígitos, DDD sem zero.
    def phone_must_be_valid
      return if phone.blank? || phone.match?(/\A[1-9]\d{9,10}\z/)

      errors.add(:phone, "Telefone inválido: use DDD e número, como (27) 99999-9999")
    end
  end
end
