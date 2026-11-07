class CustomerSessionsController < StorefrontController
  allow_unauthenticated_customer_access only: %i[new create]

  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_customer_session_path, alert: "Tente novamente mais tarde." }

  def new
  end

  # Sempre texto: sem a senha no POST, `authenticate_by` levantava
  # ArgumentError e a porta respondia 500 (achado do QA, 2026-11-07).
  def create
    if customer = Customer.authenticate_by(email: params[:email].to_s, password: params[:password].to_s)
      start_new_customer_session_for(customer)
      associate_cart_with_customer(customer)
      redirect_to after_customer_authentication_url, notice: "Login realizado com sucesso."
    else
      redirect_to new_customer_session_path, alert: "E-mail ou senha inválidos."
    end
  end

  def destroy
    terminate_customer_session
    redirect_to root_path, status: :see_other
  end
end
