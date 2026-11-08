# Interesse de quem quer ser avisado quando o pré-cadastro de armarinhos abrir.
# Mantém somente os contatos e o consentimento para esse aviso; a equipe pode
# consultar, marcar como avisado ou remover a solicitação no painel admin.
class DistributorInterest < ApplicationRecord
  normalizes :email_address, with: ->(value) { value.to_s.strip.downcase }
  normalizes :whatsapp_number, with: ->(value) { value.to_s.gsub(/\D/, "") }

  validates :email_address, presence: true, length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :whatsapp_number, presence: true,
    format: { with: /\A(?:55)?[1-9]\d{9,10}\z/, message: "deve incluir DDD e número de WhatsApp" }
  validate :consent_given

  scope :awaiting_notice, -> { where(notified_at: nil) }

  def whatsapp_url_number
    return whatsapp_number if whatsapp_number.length.between?(12, 13) && whatsapp_number.start_with?("55")

    "55#{whatsapp_number}"
  end

  private

  def consent_given
    errors.add(:base, "Autorize o contato para continuar.") if consent_at.blank?
  end
end
