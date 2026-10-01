# Recuperação de senha do comprador (o `PasswordsController` cobre só admin e
# vendedor). Mesmo desenho: o link leva um token assinado de 15 minutos, a
# resposta ao pedido é sempre a mesma (não revela quem tem conta) e redefinir a
# senha encerra as sessões abertas.
class CustomerPasswordsController < StorefrontController
  allow_unauthenticated_customer_access

  before_action :set_customer_by_token, only: %i[edit update]
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_customer_password_path, alert: "Tente novamente mais tarde." }

  def new
  end

  def create
    if (customer = Customer.find_by(email: params[:email].to_s.strip))
      PasswordsMailer.customer_reset(customer).deliver_later
    end

    redirect_to new_customer_session_path, notice: "Se houver uma conta com esse e-mail, as instruções de redefinição foram enviadas."
  end

  def edit
  end

  def update
    password = params[:password].to_s

    # Senha em branco não é atribuída pelo `has_secure_password`: sem esta
    # checagem a tela diria "redefinida" sem ter mudado nada.
    if password.blank?
      redirect_to edit_customer_password_path(params[:token]), alert: "Escolha uma nova senha."
    elsif @customer.update(password: password, password_confirmation: params[:password_confirmation].to_s)
      @customer.customer_sessions.destroy_all
      redirect_to new_customer_session_path, notice: "Senha redefinida com sucesso. Entre com a nova senha."
    else
      redirect_to edit_customer_password_path(params[:token]), alert: "As senhas não coincidem."
    end
  end

  private

  def set_customer_by_token
    @customer = Customer.find_by_password_reset_token!(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to new_customer_password_path, alert: "O link de redefinição é inválido ou expirou."
  end
end
