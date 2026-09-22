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

  test "retries a transient network error once" do
    @lookup = PostalCodeLookup.new
    attempts = 0
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |_request|
      attempts += 1
      raise Net::OpenTimeout if attempts == 1

      Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
        response.define_singleton_method(:body) do
          { "logradouro" => "Rua X", "bairro" => "B", "localidade" => "C", "uf" => "SC" }.to_json
        end
      end
    end
    @lookup.instance_variable_set(:@http, fake_http)

    assert_equal "Rua X", @lookup.call("88010-000").street
    assert_equal 2, attempts
  end

  test "searches addresses by state city and street" do
    requested_path = nil
    @lookup = PostalCodeLookup.new
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |request|
      requested_path = request.path
      Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
        response.define_singleton_method(:body) do
          [
            {
              "cep" => "01310-100",
              "logradouro" => "Avenida Paulista",
              "bairro" => "Bela Vista",
              "localidade" => "São Paulo",
              "uf" => "SP"
            }
          ].to_json
        end
      end
    end
    @lookup.instance_variable_set(:@http, fake_http)

    suggestions = @lookup.search(state: "sp", city: "São Paulo", street: "Paulista")

    assert_equal "/ws/SP/S%C3%A3o%20Paulo/Paulista/json/", requested_path
    assert_equal 1, suggestions.size
    assert_equal "01310-100", suggestions.first.zip_code
    assert_equal "Avenida Paulista", suggestions.first.street
    assert_equal "Bela Vista", suggestions.first.neighborhood
  end

  test "does not search without state city and at least three street characters" do
    @lookup = PostalCodeLookup.new
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_request| flunk "should not call the API" }
    @lookup.instance_variable_set(:@http, fake_http)

    assert_empty @lookup.search(state: "SP", city: "São Paulo", street: "Av")
    assert_empty @lookup.search(state: "", city: "São Paulo", street: "Paulista")
    assert_empty @lookup.search(state: "SP", city: "SP", street: "Paulista")
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
