class Notification < ApplicationRecord
  belongs_to :recipient, polymorphic: true

  enum :kind, {
    order_confirmed: "order_confirmed",
    order_shipped: "order_shipped",
    order_delivered: "order_delivered",
    new_message: "new_message",
    order_refunded: "order_refunded",
    order_cancelled: "order_cancelled",
    seller_suspended: "seller_suspended",
    new_review: "new_review",
    seller_report_received: "seller_report_received",
    seller_pending_approval: "seller_pending_approval",
    payment_declined: "payment_declined"
  }

  validates :kind, :title, :body, presence: true

  scope :chronological, -> { order(created_at: :desc) }
  scope :unread, -> { where(read_at: nil) }

  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  # Não há um admin único: todo `User` com papel `admin` recebe a mesma
  # notificação, cada um com sua própria linha (para marcar como lida sem
  # afetar os demais).
  def self.notify_admins!(kind:, title:, body:, url: nil)
    User.admin.find_each do |admin|
      create!(recipient: admin, kind: kind, title: title, body: body, url: url)
    end
  end
end
