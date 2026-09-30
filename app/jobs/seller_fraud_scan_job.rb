class SellerFraudScanJob < ApplicationJob
  queue_as :default

  def perform
    alerts = Fraud::SellerScan.new.call
    return if alerts.empty?

    alerts.each { |alert| report_to_sentry(alert) }
    FraudAlertMailer.new_alerts(alerts.map(&:id)).deliver_later
  end

  private

  # Sem PII: só o id do vendedor e a regra. O fingerprint agrupa as ocorrências
  # do mesmo vendedor e regra numa única issue.
  def report_to_sentry(alert)
    Sentry.capture_message(
      "Alerta de fraude: #{alert.rule}",
      level: :warning,
      fingerprint: [ "fraud-alert", alert.rule, alert.seller_id.to_s ],
      extra: { seller_id: alert.seller_id, fraud_alert_id: alert.id }
    )
  end
end
