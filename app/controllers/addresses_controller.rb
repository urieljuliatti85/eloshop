class AddressesController < StorefrontController
  # Sempre a partir do cliente da sessão, nunca de `Address.find`: senão um id
  # trocado na URL alcança o endereço de outra pessoa.
  before_action :set_address, only: %i[edit update destroy]

  def index
    @addresses = Current.customer.addresses.order(created_at: :desc)
  end

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

  def edit
  end

  def update
    if @address.update(address_params)
      redirect_to addresses_path, notice: "Endereço atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Apagar um endereço não afeta pedidos já feitos: o `Order` guarda o
  # snapshot do endereço usado na compra (§25).
  def destroy
    @address.destroy
    redirect_to addresses_path, notice: "Endereço removido."
  end

  private

  def set_address
    @address = Current.customer.addresses.find(params[:id])
  end

  def address_params
    params.expect(address: [ :street, :number, :complement, :neighborhood, :city, :state, :zip_code ])
  end

  def safe_return_path
    url_from(params[:return_to]) || root_path
  end
end
