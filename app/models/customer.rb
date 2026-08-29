class Customer < ApplicationRecord
  has_secure_password
  has_many :customer_sessions, dependent: :destroy
  has_many :addresses, dependent: :destroy
  has_many :orders

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
