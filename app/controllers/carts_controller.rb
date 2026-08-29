class CartsController < StorefrontController
  allow_unauthenticated_customer_access

  def show
    @cart = Current.cart
  end
end
