require "test_helper"

# A seleção do gateway é o que separa "cobrança simulada" de "dinheiro de
# verdade", e as duas pontas erradas custam caro: simular em produção entrega
# mercadoria de graça, cobrar de verdade em desenvolvimento tira dinheiro de
# quem só estava testando.
class GatewaysTest < ActiveSupport::TestCase
  test "defaults to the simulated gateway outside production" do
    assert_instance_of Gateways::FakeGateway, Gateways.build(nil)
    assert_instance_of Gateways::FakeGateway, Gateways.build("")
    assert_instance_of Gateways::FakeGateway, Gateways.build("fake")
  end

  test "builds the real gateway only when explicitly named" do
    assert_instance_of Gateways::MercadoPago, Gateways.build("mercado_pago")
  end

  # Um nome errado na variável de ambiente não pode cair silenciosamente no
  # gateway simulado: a loja passaria a "aprovar" pagamentos sem cobrar nada.
  test "refuses an unknown gateway instead of falling back" do
    assert_raises(Gateways::UnknownGateway) { Gateways.build("paypal") }
  end

  # O gateway simulado aprova pagamento sem cobrar, e o segredo que o autentica
  # é constante num repositório público — em produção ele não pode existir nem
  # por omissão da variável.
  test "refuses the simulated gateway in production, configured or not" do
    in_production do
      assert_raises(Gateways::SimulatedGatewayInProduction) { Gateways.build(nil) }
      assert_raises(Gateways::SimulatedGatewayInProduction) { Gateways.build("") }
      assert_raises(Gateways::SimulatedGatewayInProduction) { Gateways.build("fake") }
    end
  end

  test "still builds the real gateway in production" do
    in_production do
      assert_instance_of Gateways::MercadoPago, Gateways.build("mercado_pago")
    end
  end

  # Um nome desconhecido continua sendo erro de nome, e não vira o erro de
  # ambiente — a mensagem tem de apontar para o problema certo.
  test "an unknown gateway in production is still reported as unknown" do
    in_production do
      assert_raises(Gateways::UnknownGateway) { Gateways.build("paypal") }
    end
  end

  private

  def in_production
    original = Rails.env
    Rails.env = "production"
    yield
  ensure
    Rails.env = original
  end
end
