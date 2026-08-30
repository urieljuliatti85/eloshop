class CartsController < StorefrontController
  allow_unauthenticated_customer_access

  # Sem isso, dá pra tentar adivinhar códigos de cupom válidos por força
  # bruta — ver docs/security.md.
  rate_limit to: 10, within: 3.minutes, only: :apply_coupon, with: -> { redirect_to cart_path, alert: "Muitas tentativas. Tente novamente em alguns minutos." }

  def show
    @cart = Current.cart
  end

  def apply_coupon
    coupon = Coupon.find_by(code: params[:code].to_s.strip.upcase)

    if coupon&.valid_for?(Current.cart.subtotal_cents)
      Current.cart.update!(coupon: coupon)
      redirect_to cart_path, notice: "Cupom #{coupon.code} aplicado."
    else
      redirect_to cart_path, alert: "Cupom inválido ou expirado."
    end
  end

  def remove_coupon
    Current.cart.update!(coupon: nil)
    redirect_to cart_path, notice: "Cupom removido."
  end
end
