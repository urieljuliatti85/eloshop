# Seleção do gateway de pagamento em uso.
#
# O default é o gateway simulado em TODOS os ambientes, produção inclusive:
# trocar por dinheiro de verdade é uma decisão operacional explícita, feita
# definindo PAYMENT_GATEWAY=mercado_pago, e não um efeito colateral de um
# deploy. Isso também dá um caminho de volta imediato se a integração
# apresentar problema — basta remover a variável e reiniciar.
module Gateways
  class UnknownGateway < StandardError; end

  def self.build(name = ENV["PAYMENT_GATEWAY"])
    case name.to_s
    when "", "fake" then FakeGateway.new
    when "mercado_pago" then MercadoPago.new
    else raise UnknownGateway, "gateway de pagamento desconhecido: #{name}"
    end
  end
end
