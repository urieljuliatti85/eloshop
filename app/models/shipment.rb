class Shipment < ApplicationRecord
  class InvalidStatusTransition < StandardError; end

  ALLOWED_STATUS_TRANSITIONS = {
    "pending" => %w[shipped],
    "shipped" => %w[delivered],
    "delivered" => [],
    "returned" => []
  }.freeze

  belongs_to :seller_order
  delegate :order, to: :seller_order

  enum :status, {
    pending: "pending",
    shipped: "shipped",
    delivered: "delivered",
    returned: "returned"
  }, default: :pending

  validates :carrier, :service, :shipping_cents, :estimated_days, presence: true
  validates :shipping_cents, :estimated_days, numericality: { greater_than_or_equal_to: 0 }

  def local_pickup?
    service == Shipping::Quote::LOCAL_PICKUP_SERVICE
  end

  # Pago e ainda por postar: a janela em que o ateliê compra a etiqueta e,
  # por isso, vê o CPF inteiro do destinatário no painel.
  def awaiting_dispatch?
    pending? && !local_pickup? && (seller_order.confirmed? || seller_order.partially_refunded?)
  end

  def mark_shipped!(carrier: nil, service: nil, tracking_code: nil)
    transition_to!(
      "shipped",
      shipped_at: Time.current,
      carrier: carrier.presence || self.carrier,
      service: service.presence || self.service,
      tracking_code: tracking_code.presence
    )
    seller_order.record_production_start_from_shipping!
  end

  def mark_delivered!
    transition_to!("delivered", delivered_at: Time.current)
  end

  # Sinal do cliente de que o pedido chegou — deliberadamente separado do
  # status oficial (`delivered`), que só o vendedor fecha. Sem prova de
  # entrega (foto, assinatura, rastreio validado), um clique do comprador
  # não é autoridade suficiente para fechar a entrega de forma irreversível
  # nem, no futuro, para liberar repasse — decisão de negócio revisitada em
  # 2026-09-24 depois de considerar o risco de clique precoce/indevido.
  # Devolve `true` só no primeiro aviso: clicar de novo não muda a data
  # registrada nem deve repetir e-mail e notificação ao artesão.
  def report_delivered_by_customer!
    with_lock do
      raise InvalidStatusTransition, "o envio precisa estar marcado como enviado" unless shipped?
      next false if customer_reported_delivered_at?

      update!(customer_reported_delivered_at: Time.current)
    end
  end

  private

  # Trava o SellerOrder antes do envio, e não só a linha do envio: é o mesmo
  # lock que Payments::Refund toma ao reservar o valor de um reembolso. Assim
  # "marcar como enviado" e "reembolsar" ficam serializados — ou o envio
  # entra primeiro e o reembolso acontece depois de enviado, ou o reembolso
  # integral reserva o valor primeiro e o envio é recusado. Ordem dos locks:
  # SellerOrder → Shipment aqui; Payment → SellerOrder no reembolso; nenhum
  # caminho trava Shipment antes de SellerOrder.
  def transition_to!(new_status, timestamp)
    seller_order.with_lock do
      lock!
      unless seller_order.confirmed? || seller_order.partially_refunded?
        raise InvalidStatusTransition, "o pagamento precisa estar confirmado antes de atualizar a entrega"
      end

      if new_status == "shipped" && seller_order.full_refund_in_progress?
        raise InvalidStatusTransition, "há um reembolso integral em andamento neste pedido; não envie a peça"
      end

      # O comprador desistiu antes do envio (ADR 008, decisão A): postar agora
      # criaria um frete de ida e volta. Libera quando a EloShop fecha a
      # solicitação (ex.: o comprador voltou atrás).
      if new_status == "shipped" && (withdrawal = seller_order.return_requests.open.kind_withdrawal.first)
        raise InvalidStatusTransition,
          "o comprador pediu para desistir da compra (#{withdrawal.protocol}); não envie a peça. A EloShop vai responder e avisar se o envio voltar a valer"
      end

      unless ALLOWED_STATUS_TRANSITIONS.fetch(status).include?(new_status)
        raise InvalidStatusTransition, "não é possível transicionar a entrega de #{status} para #{new_status}"
      end

      update!(status: new_status, **timestamp)
    end
  end
end
