class SellerLaunchMailer < ApplicationMailer
  # Aprovação do ateliê. Durante o pré-cadastro avisa que a loja está pronta
  # e que as vendas ainda vão abrir; depois, que o catálogo já está à venda.
  def approved(seller, recipient)
    @seller = seller
    @sales_open = PlatformSetting.sales_open?
    @pre_launch_notice = PlatformSetting.pre_launch_notice(ready: seller.setup_steps.values.all?)

    mail(to: recipient, subject: "Seu ateliê foi aprovado na EloShop, #{seller.name}!")
  end

  # Fim do pré-cadastro: as vendas abriram. Também pede que o artesão divulgue
  # a página dele, agora que ela já vende.
  def sales_opened(seller, recipient)
    @seller = seller

    mail(to: recipient, subject: "As vendas da EloShop abriram, #{seller.name}!")
  end
end
