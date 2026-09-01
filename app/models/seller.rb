class Seller < ApplicationRecord
  class VerificationRequired < StandardError; end

  enum :status, {
    pending: "pending",
    approved: "approved",
    suspended: "suspended"
  }, default: "pending"

  has_many :users, dependent: :restrict_with_error
  has_many :products, dependent: :restrict_with_error
  has_many :seller_orders, dependent: :restrict_with_error

  before_validation :assign_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :mercado_pago_user_id, uniqueness: true, allow_blank: true

  def approve!(kyc_level_6_confirmed: false)
    unless mercado_pago_connected? && mercado_pago_live_mode? && kyc_level_6_confirmed
      raise VerificationRequired, "Conecte uma conta Mercado Pago de produção e confirme o KYC nível 6 antes da aprovação."
    end

    update!(status: :approved, approved_at: Time.current)
  end

  def suspend!
    update!(status: :suspended, approved_at: nil)
  end

  def mercado_pago_connected?
    mercado_pago_user_id.present? &&
      mercado_pago_access_token_ciphertext.present? &&
      mercado_pago_refresh_token_ciphertext.present?
  end

  def connect_mercado_pago!(credentials)
    connection_attributes = {
      mercado_pago_user_id: credentials.user_id,
      mercado_pago_access_token_ciphertext: credential_encryptor.encrypt_and_sign(credentials.access_token),
      mercado_pago_refresh_token_ciphertext: credential_encryptor.encrypt_and_sign(credentials.refresh_token),
      mercado_pago_token_expires_at: credentials.expires_at,
      mercado_pago_connected_at: Time.current,
      mercado_pago_live_mode: credentials.live_mode
    }
    if mercado_pago_user_id != credentials.user_id
      connection_attributes.merge!(status: :pending, approved_at: nil)
    end

    update!(connection_attributes)
  end

  def disconnect_mercado_pago!
    update!(
      mercado_pago_user_id: nil,
      mercado_pago_access_token_ciphertext: nil,
      mercado_pago_refresh_token_ciphertext: nil,
      mercado_pago_token_expires_at: nil,
      mercado_pago_connected_at: nil,
      mercado_pago_live_mode: false,
      status: :pending,
      approved_at: nil
    )
  end

  def mercado_pago_access_token
    decrypt_credential(mercado_pago_access_token_ciphertext)
  end

  def mercado_pago_refresh_token
    decrypt_credential(mercado_pago_refresh_token_ciphertext)
  end

  def to_param
    slug
  end

  private

  CREDENTIAL_ENCRYPTION_SALT = "seller-mercado-pago-oauth".freeze

  def credential_encryptor
    key = Rails.application.key_generator.generate_key(
      CREDENTIAL_ENCRYPTION_SALT,
      ActiveSupport::MessageEncryptor.key_len
    )
    ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
  end

  def decrypt_credential(ciphertext)
    credential_encryptor.decrypt_and_verify(ciphertext) if ciphertext.present?
  end

  def assign_slug
    self.slug = name.parameterize
  end
end
