class FunnelEvent < ApplicationRecord
  # Funil de compra: o que o painel de análises mostra hoje.
  BUYER_EVENT_NAMES = %w[
    view_catalog
    view_product
    add_to_cart
    checkout_started
    payment_started
    order_confirmed
    payment_failed
  ].freeze

  # Entrada do vendedor: o clique em "Conectar Mercado Pago", a volta com a
  # conexão gravada e a volta que falhou (retorno inválido, erro do Mercado
  # Pago ou conta que não pôde ser salva). Quem clicou e não aparece em nenhum
  # dos outros dois desistiu dentro da tela do Mercado Pago.
  SELLER_EVENT_NAMES = %w[
    seller_mp_connect_started
    seller_mp_connect_completed
    seller_mp_connect_failed
  ].freeze

  EVENT_NAMES = (BUYER_EVENT_NAMES + SELLER_EVENT_NAMES).freeze

  belongs_to :product, optional: true
  belongs_to :seller, optional: true

  validates :event_name, inclusion: { in: EVENT_NAMES }
  validates :occurred_on, presence: true
  validates :event_count, numericality: { greater_than_or_equal_to: 0 }
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :within, ->(range) { where(occurred_on: range) }
end
