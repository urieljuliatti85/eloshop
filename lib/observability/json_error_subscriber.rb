require "json"

module Observability
  # Rails.error cobre exceções de requests, jobs e código que usa o reporter.
  # Mantém apenas contexto de correlação conhecido; mensagens e argumentos não
  # entram no JSON porque podem conter dados fornecidos pelo cliente.
  class JsonErrorSubscriber
    SAFE_CONTEXT_KEYS = %i[request_id job_id].freeze

    def initialize(io: $stderr)
      @io = io
    end

    def report(error, handled:, severity:, context:, source:)
      @io.puts(JSON.generate({
        message: "application.error",
        level: level_for(severity),
        event: "application.error",
        exception_class: error.class.name,
        handled: handled,
        source: source,
        backtrace: Array(error.backtrace).first(10)
      }.merge(context.slice(*SAFE_CONTEXT_KEYS))))
    rescue StandardError
      nil # o reporter de erros também precisa ser à prova de falhas
    end

    private

    def level_for(severity)
      severity == :warning ? "warn" : severity.to_s
    end
  end
end
