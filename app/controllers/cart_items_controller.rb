class CartItemsController < StorefrontController
  allow_unauthenticated_customer_access

  before_action :set_cart_item, only: %i[update destroy]

  def create
    requested_quantity = params[:quantity].presence&.to_i || 1

    new_item = Current.cart.cart_items.build(
      product_id: params[:product_id],
      product_variant_id: params[:product_variant_id].presence,
      personalizations: personalization_params
    )
    # Roda os before_validation (normalização + digest) sem persistir, só
    # para descobrir a identidade completa do item (produto + variante +
    # personalização) e então decidir se soma quantidade num item existente
    # ou cria uma linha nova.
    new_item.valid?

    item = Current.cart.cart_items.find_by(
      product_id: new_item.product_id,
      product_variant_id: new_item.product_variant_id,
      personalization_digest: new_item.personalization_digest
    ) || new_item

    item.quantity = (item.persisted? ? item.quantity : 0) + requested_quantity

    if item.save
      redirect_to cart_path, notice: "Produto adicionado ao carrinho."
    else
      fallback_path = item.product ? product_path(item.product.seller, item.product.slug) : products_path
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

  # Não é mass-assignment: cada entrada só vira {option_id, value} — o
  # próprio CartItem rejeita (na validação) qualquer option_id que não
  # pertença ao produto sendo adicionado.
  def personalization_params
    raw = params[:personalizations]
    return [] if raw.blank?

    raw.to_unsafe_h.map { |option_id, value| { "personalization_option_id" => option_id, "value" => value } }
  end
end
