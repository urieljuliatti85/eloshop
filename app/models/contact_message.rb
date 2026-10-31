class ContactMessage
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :email, :string
  attribute :subject, :string
  attribute :message, :string

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :message, presence: true

  # O formulário é aberto e já foi alvo de spam automatizado que esgotou a cota
  # de e-mails. Defesa sem depender do IP (que chega como o do proxy da Railway):
  # um token assinado carimbado na renderização, que o envio só aceita depois de
  # alguns segundos (bot posta na hora) e dentro de um dia, e um campo isca que
  # humano não vê.
  MIN_FILL_SECONDS = 3
  TOKEN_TTL = 1.day

  def self.issue_token
    verifier.generate(Time.current.to_i, expires_in: TOKEN_TTL)
  end

  # `nil` = ok; senão o motivo: :honeypot (bot) ou :token (ausente, inválido,
  # expirado ou rápido demais).
  def self.rejection_for(token:, honeypot:)
    return :honeypot if honeypot.present?

    issued_at = verifier.verified(token.to_s)
    :token unless issued_at && Time.current.to_i - issued_at >= MIN_FILL_SECONDS
  end

  def self.verifier
    Rails.application.message_verifier(:contact_form)
  end
  private_class_method :verifier
end
