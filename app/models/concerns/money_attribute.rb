# Aceita preço digitado em reais ("40,00", "R$ 1.299,90") e guarda em
# centavos, que continua sendo a unidade do banco (§20).
#
# A conversão passa por BigDecimal, nunca Float: `(40.10 * 100).round` dá
# 4009 em Float, porque 40,10 não tem representação binária exata. É o
# mesmo caminho que o campo de reembolso do admin já usava.
#
# Escrever em `price_cents` diretamente continua funcionando — o formulário
# é que passa a mandar `price`.
module MoneyAttribute
  extend ActiveSupport::Concern

  class_methods do
    # Define `price` / `price=` sobre uma coluna `price_cents`.
    def money_attribute(name)
      cents = :"#{name}_cents"

      define_method(name) do
        value = public_send(cents)
        value && value / 100r
      end

      define_method(:"#{name}=") do |value|
        public_send(:"#{cents}=", MoneyAttribute.to_cents(value))
      end
    end
  end

  # nil para entrada vazia (campo opcional continua opcional) e para lixo
  # que não é número — assim a validação de presença do modelo reclama, em
  # vez de o registro salvar 0 silenciosamente.
  def self.to_cents(value)
    return value if value.is_a?(Integer)
    return nil if value.blank?

    digits = value.to_s.strip.gsub(/[^\d,.\-]/, "")
    return nil if digits.blank?

    # "1.299,90" (pt-BR) e "1299.90" convivem: quando há vírgula, ela é o
    # separador decimal e o ponto é de milhar.
    digits = digits.tr(".", "").tr(",", ".") if digits.include?(",")

    (BigDecimal(digits) * 100).round.to_i
  rescue ArgumentError
    nil
  end
end
