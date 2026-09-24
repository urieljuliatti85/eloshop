class SendWelcomeCustomerJob < ApplicationJob
  queue_as :default

  # Cliente apagado entre o enfileiramento e a execução não é erro: nada a
  # enviar. Sem isso o job ficaria repetindo até esgotar as tentativas.
  discard_on ActiveJob::DeserializationError

  def perform(customer)
    WelcomeMailer.welcome_customer(customer).deliver_now
  end
end
