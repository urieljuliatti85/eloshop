class WelcomeMailer < ApplicationMailer
  # Boas-vindas ao cliente que acabou de criar conta na loja.
  def welcome_customer(customer)
    @customer = customer

    mail(
      to: @customer.email,
      subject: "Bem-vindo à EloShop, #{@customer.name}!"
    )
  end

  # Boas-vindas ao artesão que acabou de se cadastrar como vendedor.
  # Cadastro cria o `Seller` e o `User` na mesma transação
  # (SellerRegistrationsController#create), então o e-mail sempre tem para
  # quem ir — diferente do NotifySellerOfOrderJob, que lida com ateliês sem
  # usuário vinculado por terem sido criados antes desse vínculo existir.
  def welcome_seller(seller, recipient)
    @seller = seller

    mail(
      to: recipient,
      subject: "Bem-vindo à EloShop, #{@seller.name}!"
    )
  end
end
