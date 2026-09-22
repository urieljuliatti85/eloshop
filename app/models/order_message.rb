class OrderMessage < ApplicationRecord
  MAX_BODY_LENGTH = 2_000

  belongs_to :seller_order
  belongs_to :sender, polymorphic: true

  scope :chronological, -> { order(:created_at, :id) }

  validates :sender_type, inclusion: { in: %w[Customer User] }
  validates :body, presence: true, length: { maximum: MAX_BODY_LENGTH }
  validate :sender_belongs_to_conversation
  validate :conversation_accepts_messages, on: :create

  def sent_by_customer?
    sender_type == "Customer"
  end

  private

  def sender_belongs_to_conversation
    return if seller_order.blank? || sender.blank?

    participant = if sent_by_customer?
      sender == seller_order.order.customer
    else
      sender.seller? && sender.seller_id == seller_order.seller_id
    end

    errors.add(:sender, "não participa deste pedido") unless participant
  end

  def conversation_accepts_messages
    return if seller_order.blank? || seller_order.accepts_messages?

    errors.add(:seller_order, "só aceita mensagens depois da confirmação do pagamento")
  end
end
