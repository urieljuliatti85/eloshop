module ReturnRequests
  # Roda um aviso de uma solicitação (e-mail, notificação) depois do commit sem
  # deixar a falha dele derrubar a resposta nem os outros avisos: a
  # confirmação legal é o protocolo na tela (ADR 008, regra 10).
  #
  # A falha vai explicitamente para o Sentry, com a solicitação na tag: o
  # sentry-rails não está inscrito no Rails.error
  # (`config.rails.register_error_subscriber` é false), então
  # `Rails.error.handle` sozinho só deixaria uma linha no log, sem dizer qual
  # solicitação ficou sem aviso. O `Rails.error.report` mantém essa linha.
  def self.deliver_safely(return_request)
    yield
  rescue StandardError => e
    Rails.error.report(e, handled: true, context: { return_request_id: return_request.id })
    Sentry.capture_exception(e, tags: { return_request_id: return_request.id, protocol: return_request.protocol })
    nil
  end
end
