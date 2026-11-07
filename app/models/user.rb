class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :seller_terms_acceptances, dependent: :restrict_with_error
  has_many :order_messages, as: :sender, dependent: :restrict_with_error
  has_many :notifications, as: :recipient, dependent: :destroy
  belongs_to :seller, optional: true

  enum :role, { admin: "admin", seller: "seller" }, default: "admin"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :seller, presence: true, if: :seller?
  validates :seller, absence: true, if: :admin?

  # A plataforma não pode ficar sem quem a administre: remover o último admin
  # deixaria o painel inacessível, sem caminho de volta pela interface.
  before_destroy :ensure_another_admin_remains, if: :admin?

  # Qual porta a conta usa: `:admin`, `:atelier` ou `:distributor`. É o papel
  # perguntado num lugar só (ADR 007): login, painéis, menu público e destino
  # depois de entrar partem daqui, em vez de cada um combinar `seller?` com o
  # tipo do vendedor por conta própria.
  def portal
    return :admin if admin?

    seller&.distributor? ? :distributor : :atelier
  end

  def last_admin?
    admin? && User.admin.where.not(id: id).none?
  end

  private

  def ensure_another_admin_remains
    return unless last_admin?

    errors.add(:base, "Não é possível remover o último administrador.")
    throw :abort
  end
end
