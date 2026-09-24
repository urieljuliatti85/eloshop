class Notification < ApplicationRecord
  belongs_to :recipient, polymorphic: true

  enum :kind, { order_confirmed: "order_confirmed", order_delivered: "order_delivered", new_message: "new_message" }

  validates :kind, :title, :body, presence: true

  scope :chronological, -> { order(created_at: :desc) }
  scope :unread, -> { where(read_at: nil) }

  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end
end
