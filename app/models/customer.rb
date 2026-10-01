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

  # Link de descadastro do lembrete de carrinho: assinado, sem expirar (quem
  # abre um e-mail antigo ainda precisa conseguir parar de receber).
  generates_token_for :cart_reminder_unsubscribe

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
