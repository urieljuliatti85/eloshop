# Item de uma solicitação pós-venda (ADR 008, decisão B). Na Fase 1 a
# solicitação é sempre do pedido inteiro, então todos os itens entram com a
# quantidade comprada; a Fase 2 passa a deixar o comprador escolher.
class ReturnRequestItem < ApplicationRecord
  belongs_to :return_request
  belongs_to :order_item

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
end
