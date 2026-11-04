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
      { path: seller_shipping_settings_path, title: "Frete e entregas",
        body: "Conecte aqui a sua conta da SuperFrete, com o passo a passo. Ela cota o frete pelos Correios e é obrigatória para vender." },
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

  # Abas inferiores do celular (layouts/_seller_mobile_tabs) enquanto o
  # cadastro não está pronto: o início e as quatro etapas que dependem do
  # artesão (a aprovação é da plataforma), cada uma aberta no bloco Primeiros
  # passos do /painel. `mark`: :done (✓ verde) ou :next (ponto vermelho).
  def seller_setup_tabs(steps)
    slugs = SellerPortal::GettingStartedController::STEP_SLUGS
    next_step = steps.key(false)
    step_tab = lambda do |step, label, active|
      { icon: step, label: label, path: seller_root_path(etapa: slugs[step], anchor: "primeiros-passos"), active: active,
        mark: (steps[step] ? :done : (:next if step == next_step)) }
    end

    [
      { icon: :home, label: "Início", path: seller_root_path, active: request.path == seller_root_path },
      step_tab.call(:address, "Endereço", controller_name == "ateliers"),
      step_tab.call(:mercado_pago, "Mercado Pago", controller_name == "mercado_pago_guides"),
      step_tab.call(:pix_key, "PIX", controller_name == "pix_key_guides"),
      (step_tab.call(:superfrete, "Frete", controller_name == "shipping_settings") if steps.key?(:superfrete)),
      step_tab.call(:product, "Peça", controller_name.in?(%w[products product_variants personalization_options]))
    ].compact
  end

  # Com o cadastro pronto, as abas viram o trabalho do dia na ordem em que
  # acontece: preparar os pedidos pagos (com a contagem), cadastrar peça,
  # cuidar do catálogo e responder os clientes. A aba ativa é a mesma área
  # marcada no menu lateral (`active_path`).
  def seller_work_tabs(active_path, to_prepare_count)
    [
      { icon: :home, label: "Início", path: seller_root_path },
      { icon: :orders, label: "Pedidos", path: seller_orders_path,
        mark: (to_prepare_count if to_prepare_count.positive?),
        mark_label: "#{to_prepare_count} para preparar e enviar" },
      { icon: :new_product, label: "Nova peça", path: new_seller_product_path },
      { icon: :products, label: "Produtos", path: seller_products_path },
      { icon: :superfrete, label: "Frete", path: seller_shipping_settings_path },
      { icon: :messages, label: "Mensagens", path: seller_messages_path }
    ].each { |tab| tab[:active] = tab[:path] == active_path }
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

  # Cores do status do produto no painel: publicado em verde (o que está à
  # venda), esgotado em âmbar (atenção), rascunho e descontinuado neutros. O
  # vermelho da marca fica para as ações. Sempre com o texto do status.
  PRODUCT_STATUS_CLASSES = {
    "draft" => "bg-stone-100 text-stone-600",
    "active" => "bg-emerald-100 text-emerald-800",
    "sold_out" => "bg-amber-100 text-amber-800",
    "discontinued" => "bg-stone-200 text-stone-600"
  }.freeze

  def seller_product_status_badge(product)
    tag.span(t(product.status, scope: "products.statuses"), class: "seller-badge #{PRODUCT_STATUS_CLASSES.fetch(product.status)}")
  end
end
