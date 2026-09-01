require "observability/json_event_subscriber"
require "observability/json_error_subscriber"

if Rails.env.production?
  Rails.event.subscribe(Observability::JsonEventSubscriber.new)
  Rails.error.subscribe(Observability::JsonErrorSubscriber.new)
end
