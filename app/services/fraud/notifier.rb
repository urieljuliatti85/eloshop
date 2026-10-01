module Fraud
  # Avisa o admin dos alertas recém-abertos: um e-mail com todos e uma mensagem
  # no Sentry por alerta. Usado pelo scan horário e pelo webhook de chargeback.
  class Notifier
    def self.call(alerts)
      return if alerts.empty?

      alerts.each { |alert| report_to_sentry(alert) }
      FraudAlertMailer.new_alerts(alerts.map(&:id)).deliver_later
    end

    # Sem PII: só o id do vendedor e a regra. O fingerprint agrupa as ocorrências
    # do mesmo vendedor e regra numa única issue.
    def self.report_to_sentry(alert)
      Sentry.capture_message(
        "Alerta de fraude: #{alert.rule}",
        level: :warning,
        fingerprint: [ "fraud-alert", alert.rule, alert.seller_id.to_s ],
        extra: { seller_id: alert.seller_id, fraud_alert_id: alert.id }
      )
    end
    private_class_method :report_to_sentry
  end
end
