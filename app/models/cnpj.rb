# Regras do CNPJ que não dependem de quem o guarda, no mesmo molde de `Cpf`.
# Usado pelo cadastro do distribuidor (`Seller`, ADR 007), onde é opcional.
#
# Desde julho de 2026 a Receita Federal emite CNPJ alfanumérico: as 12
# primeiras posições aceitam letras maiúsculas e dígitos, e os 2 dígitos
# verificadores continuam numéricos. O cálculo é o mesmo módulo 11 de sempre,
# com cada caractere valendo o código ASCII menos 48 — o que mantém o valor
# dos dígitos e dá A = 17, B = 18 e assim por diante. CNPJ só numérico continua
# válido por essa mesma conta.
module Cnpj
  module_function

  FIRST_WEIGHTS = [ 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 ].freeze
  SECOND_WEIGHTS = [ 6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 ].freeze

  # Só letras e dígitos, em maiúsculas: "12.abc.345/01de-35" → "12ABC34501DE35".
  def normalize(value)
    value.to_s.upcase.gsub(/[^0-9A-Z]/, "")
  end

  def valid?(value)
    cnpj = normalize(value)
    return false unless cnpj.match?(/\A[0-9A-Z]{12}\d{2}\z/)
    return false if cnpj.chars.uniq.one?

    check_digit(cnpj[0, 12], FIRST_WEIGHTS) == cnpj[12].to_i &&
      check_digit(cnpj[0, 13], SECOND_WEIGHTS) == cnpj[13].to_i
  end

  # "11222333000181" → "11.222.333/0001-81". Fora de 14 caracteres volta como
  # veio, para a tela de erro mostrar o que foi digitado.
  def format(value)
    cnpj = normalize(value)
    return cnpj unless cnpj.length == 14

    "#{cnpj[0, 2]}.#{cnpj[2, 3]}.#{cnpj[5, 3]}/#{cnpj[8, 4]}-#{cnpj[12, 2]}"
  end

  def check_digit(base, weights)
    sum = base.chars.zip(weights).sum { |char, weight| (char.ord - 48) * weight }
    remainder = sum % 11
    remainder < 2 ? 0 : 11 - remainder
  end
  private_class_method :check_digit
end
