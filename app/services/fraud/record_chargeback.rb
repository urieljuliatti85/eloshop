module Fraud
  # Registra o chargeback de um pagamento como alerta do vendedor. Só sinaliza:
  # o status do pedido e do pagamento não mudam, porque quem arca com o valor é
  # decisão de negócio (CLAUDE.md §69).
  #
  # Devolve o alerta apenas quando ele foi aberto agora; chargeback de outro
  # pedido do mesmo vendedor entra no alerta aberto e não repete o aviso.
  class RecordChargeback
    def initialize(payment, now: Time.current)
      @payment = payment
      @now = now
    end

    def call
      seller = @payment.order.seller_order.seller
      alert = seller.fraud_alerts.open.find_by(rule: "chargeback")

      if alert
        order_ids = (alert.detail["order_ids"].to_a | [ @payment.order_id ]).sort
        alert.update!(detail: { "order_ids" => order_ids })
        return nil
      end

      seller.fraud_alerts.create!(rule: "chargeback", detail: { "order_ids" => [ @payment.order_id ] }, detected_at: @now)
    rescue ActiveRecord::RecordNotUnique
      nil # webhook concorrente abriu o mesmo alerta
    end
  end
end
