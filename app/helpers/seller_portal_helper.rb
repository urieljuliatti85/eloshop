module SellerPortalHelper
  # Passos do tour guiado do painel. Cada um aponta para um link da navegação
  # (que existe em toda página do painel), então o tour nunca precisa
  # navegar: o controller `tour` localiza o link pelo `href`.
  def seller_tour_steps
    [
      { path: seller_getting_started_path, title: "Primeiros passos",
        body: "Comece por aqui: acompanhe o que já está pronto e o que falta para o seu ateliê vender." },
      { path: seller_atelier_path, title: "Dados do Ateliê",
        body: "Cadastre o endereço de origem do ateliê. Ele é usado nas suas entregas." },
      { path: seller_mercado_pago_guide_path, title: "Conta no Mercado Pago",
        body: "Conecte a conta que vai receber seus pagamentos. Sem ela não é possível publicar produtos.",
        alert: "Não se esqueça de cadastrar a sua chave pix na sua conta Mercado Pago!" },
      { path: seller_pix_key_guide_path, title: "Cadastro da Chave Pix",
        body: "Passo a passo, com imagens do app, para cadastrar uma chave PIX na sua conta do Mercado Pago.",
        alert: "Sem chave PIX, o pagamento por PIX dos seus clientes é recusado." },
      { path: new_seller_product_path, title: "Novo produto",
        body: "Cadastre sua primeira peça. Você pode salvar como rascunho e terminar depois." }
    ]
  end

  # Selo de estoque da lista de produtos do painel: a disponibilidade dita o
  # que contar. Sob encomenda não tem estoque físico; com variantes, o estoque
  # mora nelas (ver Product#available_for_purchase?). Devolve [texto, classes].
  def seller_stock_badge(product)
    return [ "Sob encomenda", "bg-sky-100 text-sky-800" ] if product.availability_type_made_to_order?
    return [ "Estoque nas variantes", "bg-stone-100 text-stone-700" ] if product.has_variants?

    quantity = product.stock_quantity
    if quantity.zero?
      [ product.availability_type_one_of_a_kind? ? "Peça vendida" : "Sem estoque", "bg-amber-100 text-amber-800" ]
    elsif product.availability_type_one_of_a_kind?
      [ "Peça única", "bg-stone-100 text-stone-700" ]
    elsif quantity <= Product::LOW_STOCK_THRESHOLD
      [ "Estoque baixo: #{quantity}", "bg-amber-100 text-amber-800" ]
    else
      [ "#{quantity} em estoque", "bg-stone-100 text-stone-700" ]
    end
  end
end
