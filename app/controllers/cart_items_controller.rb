class CartItemsController < StorefrontController
  allow_unauthenticated_customer_access

  before_action :set_cart_item, only: %i[update destroy]

  def create
    requested_quantity = params[:quantity].presence&.to_i || 1
    item = Current.cart.cart_items.find_or_initialize_by(product_id: params[:product_id])
    item.quantity = (item.new_record? ? 0 : item.quantity) + requested_quantity

    if item.save
      redirect_to cart_path, notice: "Produto adicionado ao carrinho."
    else
      fallback_path = item.product ? product_path(item.product) : products_path
      redirect_to fallback_path, alert: item.errors.full_messages.to_sentence
    end
  end

  def update
    if @cart_item.update(quantity: params[:quantity])
      redirect_to cart_path, notice: "Quantidade atualizada."
    else
      redirect_to cart_path, alert: @cart_item.errors.full_messages.to_sentence
    end
  end

  def destroy
    @cart_item.destroy
    redirect_to cart_path, notice: "Produto removido do carrinho."
  end

  private

  def set_cart_item
    @cart_item = Current.cart.cart_items.find(params[:id])
  end
end
