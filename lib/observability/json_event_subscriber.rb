require "json"

module Observability
  # Serializa os eventos estruturados nativos do Rails como JSON de uma linha.
  # A Railway indexa cada campo como atributo pesquisável no Log Explorer.
  class JsonEventSubscriber
    TRACKED_EVENT_PREFIXES = %w[active_job. checkout. payment.].freeze
    TRACKED_EVENT_NAMES = %w[action_controller.request_completed].freeze
    PRIVATE_PAYLOAD_KEYS = %i[arguments exception_message params].freeze

    def initialize(io: $stdout)
      @io = io
    end

    def emit(event)
      payload = event[:payload].is_a?(Hash) ? event[:payload] : { payload_class: event[:payload].class.name }
      return unless tracked?(event[:name])
      return if healthcheck?(event[:name], payload)

      payload = payload.except(*PRIVATE_PAYLOAD_KEYS)
      attributes = event.fetch(:tags, {}).merge(event.fetch(:context, {})).merge(payload)

      @io.puts(JSON.generate({
        message: event[:name],
        level: level_for(event[:name], payload),
        event: event[:name]
      }.merge(attributes)))
    rescue StandardError
      nil # observabilidade nunca pode interromper o fluxo observado
    end

    private

    def tracked?(name)
      TRACKED_EVENT_NAMES.include?(name) || TRACKED_EVENT_PREFIXES.any? { |prefix| name.start_with?(prefix) }
    end

    def healthcheck?(name, payload)
      name.start_with?("action_controller.request_") && payload[:controller] == "ReadinessController"
    end

    def level_for(name, payload)
      return "error" if payload[:exception_class].present? || payload[:status].to_i >= 500
      return "warn" if payload[:status].to_i >= 400 || name.match?(/retry|discard|failed|halted/)

      "info"
    end
  end
end
