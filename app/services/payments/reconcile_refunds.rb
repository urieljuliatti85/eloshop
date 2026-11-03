module Payments
  # Resolve reembolsos que ficaram `processing`: a chamada ao gateway esgotou o
  # tempo ou respondeu 5xx (pode ter acontecido do outro lado), ou o Mercado
  # Pago respondeu `in_process` (contingência, comum no PIX). Sem isso a
  # tentativa ficaria reservada para sempre: o valor não volta a estar
  # disponível, o admin não consegue tentar de novo e o comprador não é
  # avisado — nem quando o Mercado Pago aprova depois.
  #
  # Consulta a lista de reembolsos do pagamento no gateway e aplica o
  # resultado por Payments::Refund#settle, o mesmo caminho da chamada
  # original (contabilidade, comissão proporcional e aviso ao comprador uma
  # vez só).
  class ReconcileRefunds
    # Antes disso a resposta original (ou o webhook do pagamento) ainda pode
    # chegar pelo caminho normal.
    MINIMUM_AGE = 10.minutes
    # Tentativa sem `external_id` (a resposta se perdeu) que não aparece na
    # lista depois desse tempo não nasceu no Mercado Pago: vira `failed` e
    # libera o valor para uma nova tentativa. Uma hora dá folga larga à
    # propagação do lado do provedor; marcar cedo demais arriscaria um
    # segundo reembolso do mesmo valor.
    GIVE_UP_AFTER = 1.hour
    BATCH_SIZE = 50

    def initialize(gateway: Gateways.build, now: Time.current)
      @gateway = gateway
      @now = now
    end

    def call
      stale_refunds.find_each(batch_size: BATCH_SIZE) do |refund|
        reconcile(refund)
      end
    end

    private

    def stale_refunds
      PaymentRefund.processing
        .joins(:payment)
        .where(payments: { gateway: @gateway.name })
        .where("payment_refunds.created_at <= ?", @now - MINIMUM_AGE)
        .includes(:payment)
    end

    def reconcile(refund)
      payment = refund.payment
      remote = find_remote(refund, @gateway.refunds_for(payment: payment))

      if remote
        intent = Gateways::RefundIntent.new(external_id: remote.external_id, status: remote.status)
        applied = service_for(refund).settle(refund, intent)
        notify("payment.refund_reconciled", refund, status: remote.status)
        notify_admins_of_failure(refund) if applied.failed?
      elsif refund.external_id.blank? && refund.created_at <= @now - GIVE_UP_AFTER
        gave_up = refund.with_lock do
          next false unless refund.processing?

          refund.update!(status: "failed")
        end
        notify("payment.refund_reconciled", refund, status: "failed")
        notify_admins_of_failure(refund) if gave_up
      end
    rescue StandardError => e
      notify("payment.refund_reconcile_failed", refund, error: e.class.name)
    end

    # Com `external_id`, o próprio id identifica o reembolso. Sem ele, a
    # resposta se perdeu: adota um reembolso remoto do mesmo valor que nenhuma
    # outra tentativa local já reconheça. Duas tentativas perdidas do mesmo
    # valor no mesmo pagamento são resolvidas uma por vez, porque a primeira
    # passa a ter `external_id` antes de a segunda ser examinada.
    def find_remote(refund, remote_refunds)
      if refund.external_id.present?
        return remote_refunds.find { |remote| remote.external_id == refund.external_id }
      end

      known_ids = refund.payment.payment_refunds.where.not(external_id: nil).pluck(:external_id)
      remote_refunds.find do |remote|
        known_ids.exclude?(remote.external_id) && remote.amount_cents == refund.amount_cents
      end
    end

    def service_for(refund)
      Refund.new(
        payment: refund.payment,
        amount_cents: refund.amount_cents,
        idempotency_key: refund.idempotency_key,
        gateway: @gateway
      )
    end

    # O admin pediu o reembolso e viu "ainda está processando"; sem este aviso
    # ele não saberia que nada foi devolvido. A aprovação tardia não avisa o
    # admin de propósito: comprador e ateliê já são avisados por
    # Payments::Refund#settle, e o que exige ação dele é o "não saiu".
    def notify_admins_of_failure(refund)
      order = refund.payment.order
      Notification.notify_admins!(
        kind: :refund_failed,
        title: "Reembolso não concluído",
        body: "O Mercado Pago não concluiu o reembolso do pedido ##{order.id}. Nada foi devolvido; tente de novo pela tela do pedido.",
        url: Rails.application.routes.url_helpers.admin_order_path(order)
      )
    end

    def notify(event, refund, **details)
      Rails.event.notify(event, refund_id: refund.id, payment_id: refund.payment_id, **details)
    end
  end
end
