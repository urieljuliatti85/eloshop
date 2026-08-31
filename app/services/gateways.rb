# Seleção do gateway de pagamento em uso.
#
# Fora de produção o default é o gateway simulado, que é o que torna o
# desenvolvimento e os testes possíveis sem credencial.
#
# Em produção o simulado NÃO é selecionável — nem por omissão, nem pedindo
# `fake` explicitamente. O default anterior era o simulado em todos os
# ambientes, para que processar dinheiro de verdade fosse uma decisão
# explícita; a intenção era boa, mas a consequência era pior do que o
# problema que evitava. Com a loja no ar, o simulado aprova pagamento sem
# cobrar: `FakeGateway#verify_webhook` compara um segredo que é constante
# num repositório público, e a própria tela de pagamento traz os botões de
# simulação, então qualquer visitante marcava o próprio pedido como pago.
#
# Configuração ausente agora falha alto, em vez de simular em silêncio.
# Recusar a venda é sempre melhor que entregar de graça.
module Gateways
  class UnknownGateway < StandardError; end
  class SimulatedGatewayInProduction < StandardError; end

  def self.build(name = ENV["PAYMENT_GATEWAY"])
    case name.to_s
    when "", "fake" then simulated_gateway
    when "mercado_pago" then MercadoPago.new
    else raise UnknownGateway, "gateway de pagamento desconhecido: #{name}"
    end
  end

  # Levanta em vez de devolver o simulado em produção. Só é chamado em tempo
  # de requisição (a tela de pagamento e o webhook), então uma produção sem
  # gateway configurado ainda sobe e serve o catálogo — o que quebra é
  # exatamente a etapa que não pode ser simulada.
  def self.simulated_gateway
    if Rails.env.production?
      raise SimulatedGatewayInProduction,
            "gateway de pagamento não configurado: o simulado aprova pagamentos sem cobrar e não roda em produção. " \
            "Defina PAYMENT_GATEWAY=mercado_pago com as credenciais."
    end

    FakeGateway.new
  end
  private_class_method :simulated_gateway
end
