# Regras do CPF que não dependem de quem o guarda: só os dígitos, o módulo 11
# e as máscaras de exibição. Usado pelo cadastro do ateliê (`Seller`) e pelo
# destinatário do pedido (`Checkout::Recipient`, `Order`). Guardar e cifrar
# continua com cada modelo, cada um com o próprio salt.
module Cpf
  module_function

  def digits(value)
    value.to_s.gsub(/\D/, "")
  end

  # Módulo 11 sobre os 9 e depois os 10 primeiros dígitos. Sequência de um
  # dígito só (111.111.111-11) passa na conta, mas não é CPF. A mesma regra
  # roda no navegador (cpf_input_controller.js).
  def valid?(value)
    digits = digits(value)
    return false unless digits.match?(/\A\d{11}\z/)
    return false if digits.chars.uniq.one?

    [ 9, 10 ].all? do |length|
      sum = digits[0...length].chars.map(&:to_i).zip((length + 1).downto(2)).sum { |digit, weight| digit * weight }
      remainder = (sum * 10) % 11
      remainder = 0 if remainder == 10
      remainder == digits[length].to_i
    end
  end

  # "12345678909" → "123.456.789-09", e progressivo para o que ainda está
  # incompleto ("1234" → "123.4"), igual à máscara do navegador. Mais de 11
  # dígitos volta sem máscara, para a tela de erro mostrar o que foi digitado
  # em vez de cortar em silêncio.
  def format(value)
    digits = digits(value)
    return digits if digits.length > 11

    formatted = [ digits[0, 3], digits[3, 3], digits[6, 3] ].compact_blank.join(".")
    digits.length > 9 ? "#{formatted}-#{digits[9, 2]}" : formatted
  end

  # "***.***.***-09": só os dois últimos dígitos, para reconhecer o documento
  # sem reexpô-lo.
  def mask(value)
    digits = digits(value)
    return nil if digits.blank?

    "***.***.***-#{digits.last(2)}"
  end
end
