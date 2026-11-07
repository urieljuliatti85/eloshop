class SellerLaunchMailer < ApplicationMailer
  # Aprovação do ateliê. Durante o pré-cadastro avisa que a loja está pronta
  # e que as vendas ainda vão abrir; depois, que o catálogo já está à venda.
  def approved(seller, recipient)
    @seller = seller
    @sales_open = PlatformSetting.sales_open?
    @pre_launch_notice = PlatformSetting.pre_launch_notice(ready: seller.setup_steps.values.all?)

    # O distribuidor (ADR 007) não tem página pública nem peças: o aviso dele
    # leva ao painel em /atacado/painel.
    subject = seller.distributor? ? "Seu armarinho foi aprovado na EloShop, #{seller.name}!" : "Seu ateliê foi aprovado na EloShop, #{seller.name}!"
    mail(to: recipient, subject: subject)
  end

  # Fim do pré-cadastro: as vendas abriram. Também pede que o artesão divulgue
  # a página dele, agora que ela já vende.
  def sales_opened(seller, recipient)
    @seller = seller

    mail(to: recipient, subject: "As vendas da EloShop abriram, #{seller.name}!")
  end

  # Fim do pré-cadastro para quem está só na vitrine: a página aparece na loja,
  # mas não vende até conectar o Mercado Pago e ser aprovado.
  def sales_opened_not_accepting_orders(seller, recipient)
    @seller = seller

    mail(to: recipient, subject: "As vendas da EloShop abriram: conecte o Mercado Pago, #{seller.name}")
  end
end
