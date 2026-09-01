class AddressesController < StorefrontController
  def new
    @address = Current.customer.addresses.new
    @return_to = safe_return_path
  end

  def create
    @address = Current.customer.addresses.new(address_params)

    if @address.save
      redirect_to safe_return_path, notice: "Endereço cadastrado com sucesso."
    else
      @return_to = safe_return_path
      render :new, status: :unprocessable_entity
    end
  end

  private

  def address_params
    params.expect(address: [ :street, :number, :complement, :neighborhood, :city, :state, :zip_code ])
  end

  def safe_return_path
    url_from(params[:return_to]) || root_path
  end
end
