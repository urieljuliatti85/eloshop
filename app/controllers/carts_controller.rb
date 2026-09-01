class CartsController < StorefrontController
  allow_unauthenticated_customer_access

  # Sem isso, dá pra tentar adivinhar códigos de cupom válidos por força
  # bruta — ver docs/security.md.
  rate_limit to: 10, within: 3.minutes, only: :apply_coupon, with: -> { redirect_to cart_path, alert: "Muitas tentativas. Tente novamente em alguns minutos." }

  def show
    @cart = Current.cart
    drop_discontinued_items
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

  private

  # O CartItem valida a disponibilidade na entrada, mas nada reroda essa
  # validação depois: um produto descontinuado enquanto já estava no
  # carrinho continuava visível até o checkout recusar. Remove aqui, com
  # aviso — o cliente precisa saber por que o item sumiu (§60). O aviso não
  # nomeia o produto: descontinuado não pode aparecer em lugar nenhum, e o
  # nome na tela é justamente o que se quer eliminar.
  def drop_discontinued_items
    removed = @cart.cart_items.joins(:product).merge(Product.discontinued).destroy_all
    return if removed.empty?

    flash.now[:alert] = if removed.one?
      "Um item do seu carrinho não está mais à venda e foi removido."
    else
      "Alguns itens do seu carrinho não estão mais à venda e foram removidos."
    end
  end
end
