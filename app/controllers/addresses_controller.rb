class AddressesController < StorefrontController
  def new
    @address = Current.customer.addresses.new
  end

  def create
    @address = Current.customer.addresses.new(address_params)

    if @address.save
      redirect_to root_path, notice: "Endereço cadastrado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def address_params
    params.expect(address: [ :street, :number, :complement, :neighborhood, :city, :state, :zip_code ])
  end
end
