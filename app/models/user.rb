class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :seller, optional: true

  enum :role, { admin: "admin", seller: "seller" }, default: "admin"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :seller, presence: true, if: :seller?
  validates :seller, absence: true, if: :admin?

  # A plataforma não pode ficar sem quem a administre: remover o último admin
  # deixaria o painel inacessível, sem caminho de volta pela interface.
  before_destroy :ensure_another_admin_remains, if: :admin?

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
