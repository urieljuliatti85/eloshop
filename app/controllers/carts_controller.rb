class CartsController < StorefrontController
  def show
    @cart = Current.cart
  end
end
