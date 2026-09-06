require "test_helper"

class PostalCodeLookupTest < ActiveSupport::TestCase
  test "returns the address for a valid CEP" do
    address = stub_response({
      "logradouro" => "Rua das Flores",
      "bairro" => "Centro",
      "localidade" => "Florianópolis",
      "uf" => "SC"
    }) { @lookup.call("88010-000") }

    assert_equal "Rua das Flores", address.street
    assert_equal "Centro", address.neighborhood
    assert_equal "Florianópolis", address.city
    assert_equal "SC", address.state
  end

  test "accepts a CEP without punctuation" do
    address = stub_response({ "logradouro" => "Rua X", "bairro" => "B", "localidade" => "C", "uf" => "SC" }) do
      @lookup.call("88010000")
    end

    assert_equal "Rua X", address.street
  end

  test "returns nil for an unknown CEP" do
    address = stub_response({ "erro" => true }) { @lookup.call("00000-000") }

    assert_nil address
  end

  test "returns nil for a malformed CEP without calling the API" do
    @lookup = PostalCodeLookup.new
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_request| flunk "should not call the API" }
    @lookup.instance_variable_set(:@http, fake_http)

    assert_nil @lookup.call("123")
  end

  test "returns nil when the API is unreachable" do
    @lookup = PostalCodeLookup.new
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_request| raise Net::OpenTimeout }
    @lookup.instance_variable_set(:@http, fake_http)

    assert_nil @lookup.call("88010-000")
  end

  private

  def stub_response(payload)
    @lookup = PostalCodeLookup.new
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |_request|
      Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
        response.define_singleton_method(:body) { payload.to_json }
      end
    end
    @lookup.instance_variable_set(:@http, fake_http)

    yield
  end
end
