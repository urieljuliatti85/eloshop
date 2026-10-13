require "net/http"
require "json"

# Verificação server-side do Cloudflare Turnstile (captcha). O token que o
# widget gera no navegador só vale depois de confirmado aqui com o segredo.
#
# Só fica ativo com `TURNSTILE_SECRET_KEY` presente: sem ela (dev, teste, ou
# produção antes de o segredo ser configurado) o widget não aparece e nada é
# exigido, para o deploy nunca trancar o formulário por falta de configuração.
#
# `verify` devolve `:ok`, `:failed` (token ausente ou recusado) ou
# `:unavailable` (o Cloudflare não respondeu). Quem chama decide o que fazer
# com `:unavailable`; para formulários que não podem parar por causa de um
# terceiro, a decisão é seguir (falhar aberto) e deixar as outras defesas.
class Turnstile
  API_HOST = "challenges.cloudflare.com"
  VERIFY_PATH = "/turnstile/v0/siteverify"
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 5
  NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError ].freeze

  # Chave pública do widget (não é segredo); pode ser trocada por variável.
  DEFAULT_SITE_KEY = "0x4AAAAAAFV8Zr13IajXhWyM".freeze

  def self.enabled?
    secret_key.present?
  end

  def self.site_key
    ENV.fetch("TURNSTILE_SITE_KEY", DEFAULT_SITE_KEY)
  end

  def self.secret_key
    ENV["TURNSTILE_SECRET_KEY"]
  end

  def self.verify(token, remote_ip: nil)
    new.verify(token, remote_ip: remote_ip)
  end

  def verify(token, remote_ip: nil)
    return :ok unless self.class.enabled?
    return :failed if token.blank?

    request = Net::HTTP::Post.new(VERIFY_PATH)
    request.set_form_data({ secret: self.class.secret_key, response: token.to_s, remoteip: remote_ip }.compact)
    response = http.request(request)
    return :unavailable unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body.to_s)["success"] == true ? :ok : :failed
  rescue JSON::ParserError, *NETWORK_ERRORS
    :unavailable
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
