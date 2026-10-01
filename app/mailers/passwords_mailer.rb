class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Redefinição de senha", to: user.email_address
  end

  # Comprador: o link leva à tela de redefinição da loja, e não à de admin e
  # vendedor (`reset`). O token expira em 15 minutos e é invalidado quando a
  # senha muda, porque carrega o hash da senha atual.
  def customer_reset(customer)
    @customer = customer
    mail subject: "Redefinição de senha — EloShop", to: customer.email
  end
end
