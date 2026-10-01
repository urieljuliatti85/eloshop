# Descadastro do lembrete de carrinho, aberto pelo link do e-mail (sem login):
# a autenticidade vem do token assinado. GET só mostra a confirmação, porque
# leitores de e-mail e antivírus abrem links; quem muda o estado é o DELETE.
class CartRemindersController < StorefrontController
  allow_unauthenticated_customer_access

  before_action :set_customer

  def show
  end

  def destroy
    @customer.update!(cart_reminder_emails: false)
  end

  private

  def set_customer
    @customer = Customer.find_by_token_for(:cart_reminder_unsubscribe, params[:token])
    render :invalid, status: :not_found unless @customer
  end
end
