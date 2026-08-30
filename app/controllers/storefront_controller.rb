class StorefrontController < ApplicationController
  include Carting
  include CustomerAuthentication

  allow_unauthenticated_access

  # Autenticação de cliente NÃO é liberada aqui de forma geral: cada
  # controller decide se e quais ações ficam abertas (ver ProductsController,
  # CartsController, CartItemsController, CustomersController,
  # CustomerSessionsController). AddressesController não libera nenhuma,
  # exigindo cliente autenticado em todas as ações.

  helper_method :wishlist_item_id_for

  private

  # Carregado uma vez por request e reaproveitado em qualquer grid de
  # produtos (catálogo, PDP, relacionados) — evita N+1 de "este produto
  # está nos favoritos?" por card. Devolve o id do WishlistItem (para
  # montar o botão de remover) ou nil se o produto não estiver favoritado.
  def wishlist_item_id_for(product)
    wishlist_item_ids_by_product_id[product.id]
  end

  def wishlist_item_ids_by_product_id
    @wishlist_item_ids_by_product_id ||= customer_authenticated? ? Current.customer.wishlist_items.pluck(:product_id, :id).to_h : {}
  end
end
