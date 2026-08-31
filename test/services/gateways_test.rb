require "test_helper"

# A seleção do gateway é o que separa "cobrança simulada" de "dinheiro de
# verdade". O default precisa ser o simulado em qualquer ambiente, inclusive
# produção: processar pagamento real tem de ser uma decisão explícita.
class GatewaysTest < ActiveSupport::TestCase
  test "defaults to the simulated gateway when nothing is configured" do
    assert_instance_of Gateways::FakeGateway, Gateways.build(nil)
    assert_instance_of Gateways::FakeGateway, Gateways.build("")
  end

  test "builds the real gateway only when explicitly named" do
    assert_instance_of Gateways::MercadoPago, Gateways.build("mercado_pago")
  end

  # Um nome errado na variável de ambiente não pode cair silenciosamente no
  # gateway simulado: a loja passaria a "aprovar" pagamentos sem cobrar nada.
  test "refuses an unknown gateway instead of falling back" do
    assert_raises(Gateways::UnknownGateway) { Gateways.build("paypal") }
  end
end
