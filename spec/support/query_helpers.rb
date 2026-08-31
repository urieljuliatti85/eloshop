# Contagem de queries para as asserções de performance (Fase 17).
#
# As asserções são sempre sobre o crescimento — "não custa mais caro com mais
# dados" — e nunca sobre um número absoluto, que muda a cada alteração
# legítima de página e transformaria o teste em ruído.
module QueryHelpers
  IGNORED = %w[SCHEMA TRANSACTION].freeze

  def count_queries
    count = 0
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless payload[:name].to_s.in?(IGNORED) || payload[:cached]
    end
    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end
end
