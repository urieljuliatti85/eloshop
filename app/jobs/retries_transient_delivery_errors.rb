# Repete o envio de e-mail só quando a falha é transitória e a mensagem
# comprovadamente não foi aceita: conexão que não abriu (`Net::OpenTimeout`),
# limite de taxa (429) e erro 500 do Resend. Chave inválida ou payload
# inválido (`Resend::Error::InvalidRequestError`) falha de vez, de propósito:
# repetir não resolve e o erro precisa aparecer. `Net::ReadTimeout` também fica
# de fora, porque o Resend pode ter aceitado o envio e repetir duplicaria o
# e-mail.
module RetriesTransientDeliveryErrors
  extend ActiveSupport::Concern

  TRANSIENT_ERRORS = [
    Net::OpenTimeout,
    Resend::Error::RateLimitExceededError,
    Resend::Error::InternalServerError
  ].freeze

  included do
    retry_on(*TRANSIENT_ERRORS, wait: :polynomially_longer, attempts: 5)
  end
end
