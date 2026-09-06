require "net/http"
require "json"

# Consulta o ViaCEP no backend, não no navegador: a CSP da aplicação restringe
# connect_src a :self (docs/security.md), e abrir exceção para uma API de CEP
# enfraqueceria essa política à toa.
class PostalCodeLookup
  API_HOST = "viacep.com.br"
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 5

  Address = Data.define(:street, :neighborhood, :city, :state)

  def call(cep)
    digits = cep.to_s.gsub(/\D/, "")
    return nil unless digits.length == 8

    request = Net::HTTP::Get.new("/ws/#{digits}/json/")
    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body.to_s)
    return nil if payload["erro"]

    Address.new(
      street: payload["logradouro"].to_s,
      neighborhood: payload["bairro"].to_s,
      city: payload["localidade"].to_s,
      state: payload["uf"].to_s
    )
  rescue JSON::ParserError, Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError
    nil
  end

  private

  def http
    @http ||= Net::HTTP.new(API_HOST, 443).tap do |client|
      client.use_ssl = true
      client.open_timeout = OPEN_TIMEOUT
      client.read_timeout = READ_TIMEOUT
    end
  end
end
