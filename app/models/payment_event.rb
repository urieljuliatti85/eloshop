class PaymentEvent < ApplicationRecord
  belongs_to :payment

  validates :gateway_event_id, presence: true, uniqueness: true
end
