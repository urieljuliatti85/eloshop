class SellerOnboardingMailer < ApplicationMailer
  # Avisa a plataforma de que um vendedor conectou uma conta Mercado Pago de
  # produção e espera aprovação. A notificação dentro do admin já existe; o
  # e-mail cobre quem não está com o admin aberto.
  def awaiting_approval(seller)
    @seller = seller

    mail(to: ContactMailer::DESTINATION_EMAIL, subject: "EloShop — #{seller.name} aguarda aprovação")
  end
end
