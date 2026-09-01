class WishlistItemsController < StorefrontController
  def create
    item = Current.customer.wishlist_items.find_or_initialize_by(product_id: params[:product_id])

    if item.persisted? || item.save
      redirect_back fallback_location: wishlist_path, notice: "Adicionado aos favoritos."
    else
      redirect_back fallback_location: wishlist_path, alert: item.errors.full_messages.to_sentence
    end
  end

  def destroy
    item = Current.customer.wishlist_items.find(params[:id])
    item.destroy
    redirect_back fallback_location: wishlist_path, notice: "Removido dos favoritos."
  end

  # Só é oferecido para produtos que não exigem escolha de variante nem
  # personalização obrigatória (ver app/views/wishlist/show.html.erb) —
  # nesses casos o cliente precisa passar pela PDP para escolher.
  def move_to_cart
    item = Current.customer.wishlist_items.find(params[:id])
    product = item.product

    unless product.directly_purchasable?
      redirect_to product_path(product.seller, product.slug), alert: "Escolha as opções do produto antes de adicionar ao carrinho."
      return
    end

    new_item = Current.cart.cart_items.build(product_id: product.id)
    new_item.valid?

    cart_item = Current.cart.cart_items.find_by(
      product_id: new_item.product_id, product_variant_id: nil, personalization_digest: new_item.personalization_digest
    ) || new_item
    cart_item.quantity = (cart_item.persisted? ? cart_item.quantity : 0) + 1

    if cart_item.save
      item.destroy
      redirect_to cart_path, notice: "Produto movido para o carrinho."
    else
      redirect_to wishlist_path, alert: cart_item.errors.full_messages.to_sentence
    end
  end
end
