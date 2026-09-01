class CustomersController < StorefrontController
  allow_unauthenticated_customer_access

  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_customer_path, alert: "Tente novamente mais tarde." }

  def new
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(customer_params)

    if @customer.save
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
