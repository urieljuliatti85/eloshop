class CartsController < StorefrontController
  allow_unauthenticated_customer_access

  # Sem isso, dá pra tentar adivinhar códigos de cupom válidos por força
  # bruta — ver docs/security.md.
  rate_limit to: 10, within: 3.minutes, only: :apply_coupon, with: -> { redirect_to cart_path, alert: "Muitas tentativas. Tente novamente em alguns minutos." }

  def show
    @cart = Current.cart
    drop_discontinued_items
    drop_suspended_seller_items
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

  # Mesma lacuna do método acima, mas para o vendedor em vez do produto: um
  # item adicionado antes da suspensão do ateliê ficava no carrinho até o
  # checkout recusar (`Checkout::CreateOrder` já revalida `available_for_purchase?`
  # na criação do pedido, mas nada removia o item antes disso). O carrinho é
  # mono-vendedor (`same_seller_as_cart`), então essa remoção nunca compete
  # com a de cima por mensagem — na pior das hipóteses ambas removem itens do
  # mesmo pedido em formação, e a última mensagem prevalece.
  def drop_suspended_seller_items
    removed = @cart.cart_items.joins(product: :seller).merge(Seller.suspended).destroy_all
    return if removed.empty?

    flash.now[:alert] = if removed.one?
      "Um item do seu carrinho não está mais à venda porque o ateliê foi suspenso e foi removido."
    else
      "Alguns itens do seu carrinho não estão mais à venda porque o ateliê foi suspenso e foram removidos."
    end
  end
end
