require "test_helper"
require "stringio"

class Observability::JsonEventSubscriberTest < ActiveSupport::TestCase
  test "writes a searchable single-line JSON event" do
    output = StringIO.new
    subscriber = Observability::JsonEventSubscriber.new(io: output)

    subscriber.emit(
      name: "action_controller.request_completed",
      payload: { status: 503, duration_ms: 12.4 },
      tags: {},
      context: { request_id: "request-1" }
    )

    event = JSON.parse(output.string)
    assert_equal "action_controller.request_completed", event["message"]
    assert_equal "error", event["level"]
    assert_equal 503, event["status"]
    assert_equal "request-1", event["request_id"]
    assert_equal 1, output.string.lines.size
  end

  test "never propagates output failures" do
    broken_io = Object.new
    broken_io.define_singleton_method(:puts) { raise IOError, "closed" }

    assert_nothing_raised do
      Observability::JsonEventSubscriber.new(io: broken_io).emit(
        name: "checkout.test", payload: {}, tags: {}, context: {}
      )
    end
  end

  test "ignores unlisted framework events and private payload fields" do
    output = StringIO.new
    subscriber = Observability::JsonEventSubscriber.new(io: output)

    subscriber.emit(
      name: "action_controller.request_started",
      payload: { params: { name: "Maria" } },
      tags: {},
      context: {}
    )
    subscriber.emit(
      name: "active_job.completed",
      payload: { job_id: "job-1", exception_class: "RuntimeError", exception_message: "segredo" },
      tags: {},
      context: {}
    )

    assert_equal 1, output.string.lines.size
    assert_not_includes output.string, "Maria"
    assert_not_includes output.string, "segredo"
  end

  test "does not emit readiness request noise" do
    output = StringIO.new
    subscriber = Observability::JsonEventSubscriber.new(io: output)

    subscriber.emit(
      name: "action_controller.request_completed",
      payload: { controller: "ReadinessController", status: 200 },
      tags: {},
      context: {}
    )

    assert_empty output.string
  end

  test "writes marketplace OAuth failures without response values" do
    output = StringIO.new
    subscriber = Observability::JsonEventSubscriber.new(io: output)

    subscriber.emit(
      name: "marketplace.mercado_pago_oauth.failed",
      payload: {
        failure_reason: "invalid_payload",
        response_fields: %w[access_token expires_in user_id]
      },
      tags: {},
      context: { request_id: "request-1" }
    )

    event = JSON.parse(output.string)
    assert_equal "warn", event["level"]
    assert_equal %w[access_token expires_in user_id], event["response_fields"]
    assert_not_includes output.string, "secret-access-token"
  end

  test "keeps safe OAuth field names visible after parameter filtering" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter(response_fields: %w[access_token expires_in user_id])

    assert_equal %w[access_token expires_in user_id], filtered[:response_fields]
  end
end
