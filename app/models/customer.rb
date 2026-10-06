class Customer < ApplicationRecord
  has_secure_password
  has_many :customer_sessions, dependent: :destroy
  has_many :addresses, dependent: :destroy
  has_many :orders
  has_many :order_messages, as: :sender, dependent: :restrict_with_error
  has_many :wishlist_items, dependent: :destroy
  has_many :wishlist_products, through: :wishlist_items, source: :product
  has_many :reviews, dependent: :destroy
  has_many :seller_reports, dependent: :destroy
  has_many :notifications, as: :recipient, dependent: :destroy

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  # Resposta da conferência de e-mail do cadastro, enquanto o comprador digita.
  # Só diz se o endereço serve e está livre; a unicidade (`validates` + índice)
  # continua sendo a validação final no `create`.
  def self.email_availability(raw_email)
    email = normalize_value_for(:email, raw_email.to_s)
    # A regex padrão aceita "a@b"; um e-mail de cadastro precisa de domínio com ponto.
    return { valid: false, available: false } unless email.match?(URI::MailTo::EMAIL_REGEXP) && email.split("@").last.include?(".")

    { valid: true, available: !exists?(email: email) }
  end
end
