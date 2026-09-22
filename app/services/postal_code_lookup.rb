require "net/http"
require "json"

# Consulta o ViaCEP no backend, não no navegador: a CSP da aplicação restringe
# connect_src a :self (docs/security.md), e abrir exceção para uma API de CEP
# enfraqueceria essa política à toa.
class PostalCodeLookup
  API_HOST = "viacep.com.br"
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 5
  NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError ].freeze

  Address = Data.define(:street, :neighborhood, :city, :state)
  Suggestion = Data.define(:zip_code, :street, :neighborhood, :city, :state)

  def call(cep)
    digits = cep.to_s.gsub(/\D/, "")
    return nil unless digits.length == 8

    request = Net::HTTP::Get.new("/ws/#{digits}/json/")
    response = request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body.to_s)
    return nil if payload["erro"]

    Address.new(
      street: payload["logradouro"].to_s,
      neighborhood: payload["bairro"].to_s,
      city: payload["localidade"].to_s,
      state: payload["uf"].to_s
    )
  rescue JSON::ParserError, *NETWORK_ERRORS
    nil
  end

  def search(state:, city:, street:)
    state = state.to_s.strip.upcase
    city = city.to_s.strip
    street = street.to_s.strip
    return [] unless state.match?(/\A[A-Z]{2}\z/) && city.length >= 3 && street.length >= 3

    # Em segmentos de path o ViaCEP aceita `%20`, mas responde 404 quando o
    # espaço vem como `+` (a forma usada em query strings).
    path = [ state, city, street ].map { |part| URI.encode_www_form_component(part).gsub("+", "%20") }.join("/")
    response = request(Net::HTTP::Get.new("/ws/#{path}/json/"))
    return [] unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body.to_s)
    return [] unless payload.is_a?(Array)

    payload.filter_map do |entry|
      next unless entry.is_a?(Hash) && entry["cep"].present? && entry["logradouro"].present?

      Suggestion.new(
        zip_code: entry["cep"].to_s,
        street: entry["logradouro"].to_s,
        neighborhood: entry["bairro"].to_s,
        city: entry["localidade"].to_s,
        state: entry["uf"].to_s
      )
    end.first(10)
  rescue JSON::ParserError, *NETWORK_ERRORS
    []
  end

  private

  def request(http_request)
    attempts = 0

    begin
      attempts += 1
      http.request(http_request)
    rescue *NETWORK_ERRORS
      retry if attempts < 2

      raise
    end
  end

  def http
    @http ||= Net::HTTP.new(API_HOST, 443).tap do |client|
      client.use_ssl = true
      client.open_timeout = OPEN_TIMEOUT
      client.read_timeout = READ_TIMEOUT
    end
  end
end
