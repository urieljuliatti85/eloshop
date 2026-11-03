# Solicitação pós-venda do comprador (ADR 008): desistência, problema no
# produto ou problema na entrega, por SellerOrder — é por ateliê que se devolve
# e reembolsa. Na Fase 1, o reembolso e o estoque são feitos pelo admin pelos
# caminhos que já existem (tela do pedido, cadastro do produto); a solicitação
# registra o pedido, o protocolo do Decreto 7.962 e o atendimento.
class ReturnRequest < ApplicationRecord
  class InvalidStatusTransition < StandardError; end

  RESPONSE_BUSINESS_DAYS = 2
  # Art. 49 do CDC: 7 dias a partir do recebimento. Só informativo para o
  # admin — a desistência nunca é recusada por prazo (parecer de 2026-10-29).
  WITHDRAWAL_WINDOW_DAYS = 7
  OPEN_STATUSES = %w[received in_progress awaiting_return].freeze
  STATUS_TRANSITIONS = {
    "received" => %w[in_progress awaiting_return resolved closed],
    "in_progress" => %w[awaiting_return resolved closed],
    "awaiting_return" => %w[in_progress resolved closed],
    "resolved" => [],
    "closed" => []
  }.freeze
  # Pedido pago e ainda não reembolsado por inteiro.
  ELIGIBLE_SELLER_ORDER_STATUSES = %w[confirmed partially_refunded].freeze

  belongs_to :seller_order
  has_one :order, through: :seller_order
  has_many :items, class_name: "ReturnRequestItem", dependent: :destroy
  has_many :updates, class_name: "ReturnRequestUpdate", dependent: :destroy

  enum :kind, {
    withdrawal: "withdrawal",
    product_issue: "product_issue",
    delivery_issue: "delivery_issue"
  }, prefix: :kind

  enum :status, {
    received: "received",
    in_progress: "in_progress",
    awaiting_return: "awaiting_return",
    resolved: "resolved",
    closed: "closed"
  }, default: "received"

  validates :kind, :respond_by, presence: true
  validates :description, length: { maximum: 2000 }

  scope :open, -> { where(status: OPEN_STATUSES) }
  scope :by_deadline, -> { order(:respond_by, :id) }

  KIND_LABELS = {
    "withdrawal" => "Desistência da compra",
    "product_issue" => "Problema com o produto",
    "delivery_issue" => "Problema na entrega"
  }.freeze

  STATUS_LABELS = {
    "received" => "Recebida",
    "in_progress" => "Em andamento",
    "awaiting_return" => "Aguardando devolução",
    "resolved" => "Resolvida",
    "closed" => "Encerrada"
  }.freeze

  def self.eligible?(seller_order)
    seller_order.status.in?(ELIGIBLE_SELLER_ORDER_STATUSES)
  end

  # Motivos que o comprador ainda pode abrir pela tela. Um motivo já aberto
  # sai da lista (o atendimento segue na solicitação dele), e a desistência
  # aberta encerra a lista: enquanto o comprador desiste, os outros motivos
  # não fazem sentido. O servidor continua aceitando um envio repetido
  # (aba antiga, duplo clique), que vira mensagem na solicitação aberta.
  def self.available_kinds(seller_order)
    return [] unless eligible?(seller_order)

    open_kinds = seller_order.return_requests.open.pluck(:kind)
    return [] if open_kinds.include?("withdrawal")

    kinds.keys - open_kinds
  end

  # Segunda a sexta, sem feriados (decisão de 2026-10-31). Aberta no sábado ou
  # no domingo, conta a partir da segunda.
  def self.respond_by_for(time)
    date = time.in_time_zone.to_date
    remaining = RESPONSE_BUSINESS_DAYS
    while remaining.positive?
      date += 1
      remaining -= 1 unless date.saturday? || date.sunday?
    end
    date
  end

  def open?
    status.in?(OPEN_STATUSES)
  end

  def overdue?(today = Time.zone.today)
    open? && respond_by < today
  end

  def kind_label
    KIND_LABELS.fetch(kind)
  end

  def status_label
    STATUS_LABELS.fetch(status)
  end

  # Data de recebimento: a do ateliê ou, sem ela, o aviso do comprador.
  def delivered_on
    shipment = seller_order.shipment
    (shipment&.delivered_at || shipment&.customer_reported_delivered_at)&.in_time_zone&.to_date
  end

  # `nil` quando a entrega não foi registrada. Nunca usado para recusar.
  def within_withdrawal_window?
    return unless kind_withdrawal?
    return if delivered_on.nil?

    created_at.in_time_zone.to_date <= delivered_on + WITHDRAWAL_WINDOW_DAYS
  end

  # Atendimento do admin: muda o status e/ou responde ao comprador, com o
  # histórico na mesma transação. Devolve o registro do histórico, ou nil se
  # nada mudou.
  def record_update!(author:, body: nil, new_status: nil)
    body = body.to_s.strip.presence
    new_status = new_status.presence
    new_status = nil if new_status == status

    with_lock do
      if new_status && !STATUS_TRANSITIONS.fetch(status).include?(new_status)
        raise InvalidStatusTransition,
          "não é possível passar de \"#{status_label}\" para \"#{STATUS_LABELS.fetch(new_status, new_status)}\""
      end
      next nil if body.nil? && new_status.nil?

      from_status = status
      if new_status
        update!(status: new_status, resolved_at: new_status.in?(%w[resolved closed]) ? Time.current : nil)
      end
      updates.create!(author: author, body: body, from_status: new_status && from_status, to_status: new_status)
    end
  end
end
