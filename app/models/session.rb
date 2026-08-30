class Session < ApplicationRecord
  # Área administrativa é mais sensível que a loja — expira mais rápido.
  # Ver docs/security.md.
  INACTIVITY_TIMEOUT = 7.days

  belongs_to :user

  scope :active, -> { where(updated_at: INACTIVITY_TIMEOUT.ago..) }
end
