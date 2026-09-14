# Diagnóstico pontual para o chamado aberto com o Mercado Pago sobre o HTTP
# 500 genérico em POST /v1/payments (docs/payments.md, seção do bloqueio da
# Fase 20 Etapa B). Não é um teste automatizado: chama a API real do gateway
# (sandbox) para isolar variáveis sugeridas pelo suporte, uma por vez.
#
# Uso:
#   bin/rails "mercado_pago:diagnose_application_fee[<order_id>]"  # já rodado — application_fee descartado
#   bin/rails "mercado_pago:diagnose_request_shape[<order_id>]"    # description/tipo numérico
#
# O pedido precisa ter um seller_order cujo Seller já esteja conectado ao
# Mercado Pago (mercado_pago_connected?) — normalmente o de sandbox
# (uriel@artesao.com.br, ver CLAUDE.md). Nunca loga o access token nem o corpo
# completo da resposta — só status HTTP e código de erro.
#
# O suporte também pediu o X-Request-Id da resposta 500: nenhuma das duas
# tasks captura esse header hoje. Para correlacionar com os logs do Mercado
# Pago, use o horário de cada chamada impresso abaixo — captura-lo
# corretamente é mudança separada em app/services/gateways/mercado_pago.rb,
# fora do escopo deste diagnóstico pontual.
namespace :mercado_pago do
  desc "Isola se application_fee causa o 500 genérico em /v1/payments (sandbox)"
  task :diagnose_application_fee, [ :order_id ] => :environment do |_task, args|
    order = Order.find(args[:order_id])
    seller = connected_seller_for(order)

    puts "Pedido ##{order.id} — vendedor ##{seller.id} (#{seller.mercado_pago_test_account? ? "conta de teste" : "conta live"})"
    puts "=" * 72

    run_authorize_case("A — COM application_fee (comportamento normal)", order: order, application_fee_cents: order.seller_order.platform_fee_cents)
    run_authorize_case("B — SEM application_fee (application_fee_cents: 0)", order: order, application_fee_cents: 0)
  end

  # Isola duas hipóteses de "formatação/estrutura do request que passa e
  # explode internamente" (resposta do suporte, 2026-09-14): o payload de
  # produção usa Float para transaction_amount/application_fee
  # ((cents / 100.0).round(2), ver Gateways::MercadoPago#authorize_pix) e um
  # em-dash (—, U+2014) no `description`. Nenhum dos dois falharia validação
  # de schema (4xx) — um Float é um número válido, e um em-dash é UTF-8 válido
  # — mas ambos são o tipo de coisa que só aparece processando internamente.
  # Chamada HTTP própria, fora de Gateways::MercadoPago: a classe de produção
  # não expõe esses parâmetros como variáveis, e não vale mudar código de
  # pagamento só para uma sonda de diagnóstico.
  desc "Isola description (em-dash) e tipo numérico (Float vs Integer) como causa do 500 (sandbox)"
  task :diagnose_request_shape, [ :order_id ] => :environment do |_task, args|
    order = Order.find(args[:order_id])
    seller = connected_seller_for(order)
    access_token = Marketplace::MercadoPagoAccessToken.new(seller: seller).call

    puts "Pedido ##{order.id} — vendedor ##{seller.id}"
    puts "=" * 72

    run_raw_case("A — description com em-dash (igual à produção)", access_token: access_token,
      transaction_amount: (order.total_cents / 100.0).round(2), description: "Pedido #{order.id} — EloShop")
    run_raw_case("B — description sem em-dash (só ASCII)", access_token: access_token,
      transaction_amount: (order.total_cents / 100.0).round(2), description: "Pedido #{order.id} - EloShop")
    run_raw_case("C — transaction_amount como Integer, sem description", access_token: access_token,
      transaction_amount: order.total_cents / 100, description: nil)
  end

  def connected_seller_for(order)
    seller = order.seller_order.seller
    return seller if seller.mercado_pago_connected?

    abort "Seller ##{seller.id} não está conectado ao Mercado Pago — conecte antes de rodar o diagnóstico."
  end

  def run_authorize_case(label, order:, application_fee_cents:)
    puts "\n#{label} — #{Time.current.iso8601}"
    gateway = Gateways::MercadoPago.new
    idempotency_key = SecureRandom.uuid

    intent = gateway.authorize(
      order: order,
      idempotency_key: idempotency_key,
      application_fee_cents: application_fee_cents,
      payment_method: "pix"
    )

    puts "  OK — status=#{intent.status} external_id=#{intent.external_id} idempotency_key=#{idempotency_key}"
  rescue Gateways::MercadoPago::RequestFailed => e
    puts "  FALHOU — #{e.message} idempotency_key=#{idempotency_key}"
  rescue Gateways::MercadoPago::ConfigurationError => e
    puts "  CONFIGURAÇÃO — #{e.message}"
  end

  def run_raw_case(label, access_token:, transaction_amount:, description:)
    require "net/http"
    require "json"

    puts "\n#{label} — #{Time.current.iso8601}"
    idempotency_key = SecureRandom.uuid

    body = { transaction_amount: transaction_amount, payment_method_id: "pix", payer: { email: ENV.fetch("MERCADO_PAGO_TEST_PAYER_EMAIL") } }
    body[:description] = description if description

    http = Net::HTTP.new("api.mercadopago.com", 443)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 15

    request = Net::HTTP::Post.new("/v1/payments")
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json"
    request["X-Idempotency-Key"] = idempotency_key
    request.body = body.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      parsed = JSON.parse(response.body.to_s)
      puts "  OK — status=#{parsed["status"]} id=#{parsed["id"]} idempotency_key=#{idempotency_key}"
    else
      parsed = JSON.parse(response.body.to_s)
      puts "  FALHOU — HTTP #{response.code} error=#{parsed["error"]} message=#{parsed["message"]} idempotency_key=#{idempotency_key}"
    end
  rescue KeyError
    abort "MERCADO_PAGO_TEST_PAYER_EMAIL não configurada — necessária para o payer.email em conta de teste."
  rescue JSON::ParserError
    puts "  FALHOU — resposta ilegível (HTTP #{response&.code})"
  end
end
