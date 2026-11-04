# Avisa um ateliê da decisão sobre a categoria que ele sugeriu. Um job por
# ateliê (CategorySuggestion#notify_requesters): se um envio falhar, o retry
# repete só aquele e-mail. `notified_at` impede o segundo envio, e o
# destinatário é decidido na execução, como nos demais avisos ao ateliê.
#
# Se o enfileiramento se perder (processo morto entre o commit e o
# `perform_later`), a sugestão decidida fica com `notified_at` nulo; reenvie
# pelo console (ver docs/catalog.md, "Sugestão de categoria").
class NotifyCategorySuggestionDecisionJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(request)
    return if request.notified_at?

    suggestion = request.category_suggestion
    return if suggestion.pending?

    recipient = request.seller.users.order(:created_at).first&.email_address
    return if recipient.blank?

    mail = suggestion.accepted? ? CategorySuggestionMailer.accepted(request, recipient) : CategorySuggestionMailer.rejected(request, recipient)
    mail.deliver_now
    request.update!(notified_at: Time.current)
  end
end
