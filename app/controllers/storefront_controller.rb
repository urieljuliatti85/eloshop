class StorefrontController < ApplicationController
  include Carting
  include CustomerAuthentication

  allow_unauthenticated_access

  # Autenticação de cliente NÃO é liberada aqui de forma geral: cada
  # controller decide se e quais ações ficam abertas (ver ProductsController,
  # CartsController, CartItemsController, CustomersController,
  # CustomerSessionsController). AddressesController não libera nenhuma,
  # exigindo cliente autenticado em todas as ações.

  helper_method :wishlist_item_id_for, :account_area?

  # Marca as ações que pertencem à área do cliente: o layout mostra a
  # navegação da conta (lateral e abas do rodapé) só nelas e só com cliente
  # logado. Explícito por controller para o checkout, que mora em
  # OrdersController, não herdar o menu da conta.
  def self.account_area(**options)
    before_action(**options) { @account_area = true }
  end

  private

  def account_area?
    @account_area == true && Current.customer.present?
  end

  # Pré-cadastro: com as vendas fechadas, o servidor recusa o que levaria a um
  # pedido (carrinho, checkout, pagamento). Esconder o botão não basta — o
  # POST pode chegar direto pela rota.
  SALES_CLOSED_ALERT = "As vendas da EloShop ainda não abriram. Salve a peça nos favoritos para voltar a ela depois.".freeze

  def require_sales_open
    return if PlatformSetting.sales_open?

    redirect_back fallback_location: root_path, alert: SALES_CLOSED_ALERT
  end

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
