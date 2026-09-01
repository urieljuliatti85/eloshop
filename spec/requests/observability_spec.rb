# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Observability context", type: :request do
  it "correlates the completed request event with the response request id" do
    events = []
    subscriber = Object.new
    subscriber.define_singleton_method(:emit) { |event| events << event }
    Rails.event.subscribe(subscriber) { |event| event[:name] == "action_controller.request_completed" }

    get root_path

    event = events.find { |item| item.dig(:payload, :controller) == "HomeController" }
    expect(event).to be_present
    expect(event.dig(:context, :request_id)).to eq(response.headers["X-Request-Id"])
    expect(event.dig(:context, :http_method)).to eq("GET")
    expect(event.dig(:context, :path)).to be_nil
  ensure
    Rails.event.unsubscribe(subscriber) if subscriber
  end
end
