class WishlistsController < StorefrontController
  def show
    @wishlist_items = Current.customer.wishlist_items.includes(product: %i[product_variants seller]).order(created_at: :desc)
  end
end
