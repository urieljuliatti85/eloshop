# A conexão com a SuperFrete é etapa obrigatória e requisito da aprovação
# onde a cotação está ligada (como no ambiente de teste). Specs que montam um
# ateliê pronto ou aprovam conectam com isto.
module SuperfreteHelpers
  def connect_superfrete!(seller, email: nil)
    seller.connect_superfrete!(access_token: "superfrete-token",
      account: Marketplace::SuperfreteOauth::Account.new(id: "sf-#{seller.id}", email: email))
  end
end
