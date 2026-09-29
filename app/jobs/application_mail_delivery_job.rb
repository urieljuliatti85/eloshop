# Job do `deliver_later`. Igual ao padrão do Rails, mais a repetição de falhas
# transitórias de envio (ver RetriesTransientDeliveryErrors).
class ApplicationMailDeliveryJob < ActionMailer::MailDeliveryJob
  include RetriesTransientDeliveryErrors
end
