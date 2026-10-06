class CustomersController < StorefrontController
  allow_unauthenticated_customer_access

  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_customer_path, alert: "Tente novamente mais tarde." }

  # Limite próprio: a consulta revela se um e-mail já tem conta, o mesmo que o
  # erro do cadastro revela, então não pode virar um catálogo de e-mails.
  rate_limit to: 20, within: 1.minute, only: :email_availability, with: -> { head :too_many_requests }

  def email_availability
    render json: Customer.email_availability(params[:email].to_s.first(254))
  end

  def new
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(customer_params)

    if @customer.save
      SendWelcomeCustomerJob.perform_later(@customer)
      start_new_customer_session_for(@customer)
      associate_cart_with_customer(@customer)
      redirect_to after_customer_authentication_url, notice: "Conta criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def customer_params
    params.expect(customer: [ :name, :email, :password, :password_confirmation ])
  end
end
