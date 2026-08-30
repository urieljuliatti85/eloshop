class WishlistsController < StorefrontController
  def show
    @wishlist_items = Current.customer.wishlist_items.includes(product: :product_variants).order(created_at: :desc)
  end
end
