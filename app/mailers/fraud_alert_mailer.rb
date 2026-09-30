class FraudAlertMailer < ApplicationMailer
  DESTINATION_EMAIL = ENV.fetch("FRAUD_ALERT_EMAIL", ContactMailer::DESTINATION_EMAIL)

  # Um e-mail por rodada do scan, com todos os alertas novos. Recebe ids (não
  # objetos) para o job de entrega não serializar registros.
  def new_alerts(alert_ids)
    @alerts = FraudAlert.where(id: alert_ids).includes(:seller).recent_first

    mail(to: DESTINATION_EMAIL, subject: "EloShop — #{@alerts.size} alerta(s) de fraude de vendedor")
  end
end
