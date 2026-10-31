require "test_helper"

class TurnstileTest < ActiveSupport::TestCase
  FakeHttp = Struct.new(:response, :error) do
    def request(_request)
      raise error if error

      response
    end
  end

  def with_secret(value = "secret")
    original = ENV["TURNSTILE_SECRET_KEY"]
    ENV["TURNSTILE_SECRET_KEY"] = value
    yield
  ensure
    ENV["TURNSTILE_SECRET_KEY"] = original
  end

  def verify_with(response: nil, error: nil, token: "tok")
    turnstile = Turnstile.new
    turnstile.instance_variable_set(:@http, FakeHttp.new(response, error))
    with_secret { turnstile.verify(token, remote_ip: "203.0.113.5") }
  end

  def http_response(klass, body)
    klass.new("1.1", "200", "OK").tap { |r| r.instance_variable_set(:@read, true); r.instance_variable_set(:@body, body) }
  end

  test "is disabled without a secret and verifies nothing" do
    assert_not Turnstile.enabled?
    assert_equal :ok, Turnstile.verify(nil)
  end

  test "accepts a token the Cloudflare confirms" do
    assert_equal :ok, verify_with(response: http_response(Net::HTTPOK, { success: true }.to_json))
  end

  test "rejects a token the Cloudflare refuses" do
    assert_equal :failed, verify_with(response: http_response(Net::HTTPOK, { success: false }.to_json))
  end

  test "rejects a missing token without calling the API" do
    assert_equal :failed, verify_with(token: "", error: RuntimeError.new("should not call the API"))
  end

  test "is unavailable on network errors, bad status or garbage" do
    assert_equal :unavailable, verify_with(error: Timeout::Error.new)
    assert_equal :unavailable, verify_with(response: http_response(Net::HTTPInternalServerError, ""))
    assert_equal :unavailable, verify_with(response: http_response(Net::HTTPOK, "<html>"))
  end
end
