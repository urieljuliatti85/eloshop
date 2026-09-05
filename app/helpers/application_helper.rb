module ApplicationHelper
  # O item do menu fica marcado pelo controller da requisição, não pela URL
  # exata: "Loja" continua ativo na página de um produto, e "Painel do Artesão"
  # em qualquer tela do painel.
  def storefront_nav_active?(controllers)
    Array(controllers).include?(controller_path)
  end

  # Formata um valor em centavos para exibição, ex.: 8990 => "R$ 89,90".
  #
  # Fonte única da conversão: antes cada view dividia por conta própria, em
  # dois dialetos (`/ 100.0` na vitrine, `.fdiv(100)` no admin), e ambos
  # produzem Float — o que o §20 proíbe justamente porque 0,1 não tem
  # representação exata. Aqui a divisão é por `100r` (Rational), que chega
  # exata ao `number_to_currency`.
  #
  # `nil` vira travessão: campos opcionais (frete ainda não calculado,
  # subtotal mínimo de cupom) não devem renderizar "R$ 0,00", que é um
  # valor diferente de "não informado".
  def format_price(cents, blank: "—")
    return blank if cents.blank?

    number_to_currency(cents / 100r)
  end

  # Valor para dentro de um campo de formulário: "89,90", sem "R$" e sem
  # separador de milhar — o que o usuário edita, e o que `MoneyAttribute`
  # lê de volta.
  def price_field_value(cents)
    return nil if cents.blank?

    number_with_precision(cents / 100r, precision: 2, separator: ",", delimiter: "")
  end
end
