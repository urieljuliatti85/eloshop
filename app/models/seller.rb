class Seller < ApplicationRecord
  enum :status, {
    pending: "pending",
    approved: "approved",
    suspended: "suspended"
  }, default: "pending"

  has_many :users, dependent: :restrict_with_error
  has_many :products, dependent: :restrict_with_error

  before_validation :assign_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  def approve!
    update!(status: :approved, approved_at: Time.current)
  end

  def suspend!
    update!(status: :suspended, approved_at: nil)
  end

  def to_param
    slug
  end

  private

  def assign_slug
    self.slug = name.parameterize
  end
end
