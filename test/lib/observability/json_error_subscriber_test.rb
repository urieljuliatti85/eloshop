require "test_helper"
require "stringio"

class Observability::JsonErrorSubscriberTest < ActiveSupport::TestCase
  test "logs correlation fields without exception messages or arbitrary context" do
    output = StringIO.new
    subscriber = Observability::JsonErrorSubscriber.new(io: output)
    error = RuntimeError.new("token secreto enviado pelo cliente")
    error.set_backtrace([ "app/services/example.rb:1" ])

    subscriber.report(
      error,
      handled: false,
      severity: :error,
      context: { request_id: "request-1", email: "cliente@example.com" },
      source: "application"
    )

    event = JSON.parse(output.string)
    assert_equal "application.error", event["event"]
    assert_equal "RuntimeError", event["exception_class"]
    assert_equal "request-1", event["request_id"]
    assert_not event.key?("email")
    assert_not_includes output.string, "token secreto"
    assert_not_includes output.string, "cliente@example.com"
  end
end
