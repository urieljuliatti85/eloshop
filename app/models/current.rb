class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :cart
  attribute :customer_session
  delegate :user, to: :session, allow_nil: true
  delegate :customer, to: :customer_session, allow_nil: true
end
