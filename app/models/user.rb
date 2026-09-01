class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :seller, optional: true

  enum :role, { admin: "admin", seller: "seller" }, default: "admin"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :seller, presence: true, if: :seller?
  validates :seller, absence: true, if: :admin?
end
