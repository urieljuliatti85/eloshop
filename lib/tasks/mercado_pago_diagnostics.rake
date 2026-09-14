# Diagnóstico pontual para o chamado aberto com o Mercado Pago sobre o HTTP
# 500 genérico em POST /v1/payments (docs/payments.md, seção do bloqueio da
# Fase 20 Etapa B). Não é um teste automatizado: chama a API real do gateway
# (sandbox) para isolar se `application_fee` é o que provoca o 500, conforme
# sugerido pelo suporte do Mercado Pago.
#
# Uso:
#   bin/rails "mercado_pago:diagnose_application_fee[<order_id>]"
#
# O pedido precisa ter um seller_order cujo Seller já esteja conectado ao
# Mercado Pago (mercado_pago_connected?) — normalmente o de sandbox
# (uriel@artesao.com.br, ver CLAUDE.md). Roda duas chamadas idênticas contra
# /v1/payments, mudando apenas application_fee_cents (com e sem), cada uma com
# X-Idempotency-Key própria para não colidir uma com a outra nem com tentativas
# reais do pedido. Nunca loga o access token nem o corpo completo da resposta —
# só status HTTP e código de erro, no formato que RequestFailed já expõe.
#
# O suporte também pediu o X-Request-Id da resposta 500: Gateways::MercadoPago
# não captura esse header hoje (só usa X-Request-Id no sentido inverso, na
# verificação de assinatura de webhook). Para correlacionar com os logs do
# Mercado Pago, use o horário de cada chamada impresso abaixo — captura-lo
# corretamente é mudança separada em app/services/gateways/mercado_pago.rb,
# fora do escopo deste diagnóstico pontual.
namespace :mercado_pago do
  desc "Isola se application_fee causa o 500 genérico em /v1/payments (sandbox)"
  task :diagnose_application_fee, [ :order_id ] => :environment do |_task, args|
    order = Order.find(args[:order_id])
    seller = order.seller_order.seller

    unless seller.mercado_pago_connected?
      abort "Seller ##{seller.id} não está conectado ao Mercado Pago — conecte antes de rodar o diagnóstico."
    end

    puts "Pedido ##{order.id} — vendedor ##{seller.id} (#{seller.mercado_pago_test_account? ? "conta de teste" : "conta live"})"
    puts "=" * 72

    run_case("A — COM application_fee (comportamento normal)", order: order, application_fee_cents: order.seller_order.platform_fee_cents)
    run_case("B — SEM application_fee (application_fee_cents: 0)", order: order, application_fee_cents: 0)
  end

  def run_case(label, order:, application_fee_cents:)
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
end
