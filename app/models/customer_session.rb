class CustomerSession < ApplicationRecord
  # Ver docs/security.md.
  INACTIVITY_TIMEOUT = 30.days

  belongs_to :customer

  scope :active, -> { where(updated_at: INACTIVITY_TIMEOUT.ago..) }
end
