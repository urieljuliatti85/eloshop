class WishlistsController < StorefrontController
  def show
    # Um produto descontinuado sai do catálogo para valer: a PDP responde
    # 404, então mantê-lo aqui só ofereceria um link quebrado.
    @wishlist_items = Current.customer.wishlist_items
      .joins(:product).merge(Product.not_discontinued)
      .includes(product: %i[product_variants seller])
      .order(created_at: :desc)
  end
end
