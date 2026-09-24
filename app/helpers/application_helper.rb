module ApplicationHelper
  GOOGLE_ANALYTICS_MEASUREMENT_ID_PATTERN = /\AG-[A-Z0-9]+\z/
  GOOGLE_ANALYTICS_PUBLIC_PAGES = {
    "home#show" => { path: "/inicio", title: "Início" },
    "products#index" => { path: "/catalogo", title: "Catálogo" },
    "products#show" => { path: "/produto", title: "Produto" },
    "sellers#index" => { path: "/artesaos", title: "Artesãos" },
    "sellers#show" => { path: "/artesao", title: "Ateliê" },
    "how_it_works#show" => { path: "/como-funciona", title: "Como funciona" },
    "contacts#new" => { path: "/contato", title: "Contato" },
    "seller_registrations#new" => { path: "/seja-um-artesao", title: "Seja um artesão" },
    "credits#show" => { path: "/creditos", title: "Créditos" }
  }.freeze

  def google_analytics_measurement_id
    measurement_id = ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"].to_s.strip.upcase
    measurement_id if measurement_id.match?(GOOGLE_ANALYTICS_MEASUREMENT_ID_PATTERN)
  end

  # Somente páginas públicas e sem identidade entram no Analytics. O caminho
  # enviado é virtual e estável: não inclui slug, id, query string ou URL real.
  # Carrinho, checkout, pedidos, conta, admin e painel do artesão ficam fora.
  def google_analytics_public_page
    return unless request.get? || request.head?

    GOOGLE_ANALYTICS_PUBLIC_PAGES["#{controller_path}##{action_name}"]
  end

  # O item do menu fica marcado pelo controller da requisição, não pela URL
  # exata: "Loja" continua ativo na página de um produto, e "Painel do Artesão"
  # em qualquer tela do painel.
  def storefront_nav_active?(controllers)
    Array(controllers).include?(controller_path)
  end

  # Identidade da sessão de `User` para o menu público: rótulo do papel, quem
  # está logado, o destino do seu painel e por onde sair. O topo e o painel do
  # hambúrguer mostram o mesmo bloco, então a regra mora aqui em vez de ser
  # repetida em dois trechos de ERB que sairiam de sincronia.
  #
  # `seller.name` é seguro: `User` valida `seller` como obrigatório quando o
  # papel é `seller`, e ausente quando é `admin`.
  def user_session_identity
    return nil unless Current.user

    if Current.user.admin?
      { role_label: "Administrador", identity: Current.user.email_address,
        panel_label: "Administração", panel_path: admin_root_path,
        logout_path: session_path }
    else
      { role_label: "Artesão", identity: Current.user.seller.name,
        panel_label: "Painel do Artesão", panel_path: seller_root_path,
        logout_path: seller_logout_path }
    end
  end

  # Formata um valor em centavos para exibição, ex.: 8990 => "R$ 89,90".
  #
  # Fonte única da conversão: antes cada view dividia por conta própria, em
  # dois dialetos (`/ 100.0` na vitrine, `.fdiv(100)` no admin), e ambos
  # produzem Float — o que o §20 proíbe justamente porque 0,1 não tem
  # representação exata. Aqui a divisão é por `100r` (Rational), que chega
  # exata ao `number_to_currency`.
  #
  # `nil` vira travessão: campos opcionais (frete ainda não calculado,
  # subtotal mínimo de cupom) não devem renderizar "R$ 0,00", que é um
  # valor diferente de "não informado".
  def format_price(cents, blank: "—")
    return blank if cents.blank?

    number_to_currency(cents / 100r)
  end

  # Valor para dentro de um campo de formulário: "89,90", sem "R$" e sem
  # separador de milhar — o que o usuário edita, e o que `MoneyAttribute`
  # lê de volta.
  def price_field_value(cents)
    return nil if cents.blank?

    number_with_precision(cents / 100r, precision: 2, separator: ",", delimiter: "")
  end

  def shipping_estimate_label(shipping)
    return "Retirada combinada com o ateliê" if shipping.local_pickup?

    "Até #{shipping.estimated_days} dias úteis"
  end

  # Compartilhado entre cliente, painel do vendedor e admin — os três mostram
  # o mesmo Payment, cada um na sua tela de pedido.
  def payment_method_label(payment)
    return "PIX" if payment.pix?

    parts = [ "Cartão de crédito" ]
    parts << "#{payment.installments}×" if payment.installments > 1
    parts << "#{payment.card_brand.humanize} •••• #{payment.card_last_four}" if payment.card_last_four.present?
    parts.join(" · ")
  end

  SELLER_ORDER_FULFILLMENT_BADGE_CLASSES = {
    awaiting_payment: "bg-stone-100 text-stone-700",
    preparing: "bg-amber-100 text-amber-800",
    shipped: "bg-sky-100 text-sky-800",
    ready_for_pickup: "bg-sky-100 text-sky-800",
    delivered: "bg-emerald-100 text-emerald-800",
    picked_up: "bg-emerald-100 text-emerald-800",
    closed: "bg-stone-100 text-stone-600",
    unavailable: "bg-stone-100 text-stone-600"
  }.freeze

  # Compartilhado entre cliente e painel do vendedor — os dois mostram a
  # mesma linha do tempo de entrega do mesmo SellerOrder, cada um na própria
  # tela de pedido.
  def seller_order_fulfillment_state(seller_order)
    return :closed if seller_order.cancelled? || seller_order.refunded?
    return :awaiting_payment if seller_order.pending?

    shipment = seller_order.shipment
    return :unavailable unless shipment
    return shipment.local_pickup? ? :picked_up : :delivered if shipment.delivered?
    return shipment.local_pickup? ? :ready_for_pickup : :shipped if shipment.shipped?

    :preparing
  end

  def seller_order_fulfillment_label(seller_order)
    t(seller_order_fulfillment_state(seller_order), scope: "shipments.fulfillment_states")
  end

  def seller_order_fulfillment_badge_classes(seller_order)
    SELLER_ORDER_FULFILLMENT_BADGE_CLASSES.fetch(seller_order_fulfillment_state(seller_order))
  end

  def seller_order_timeline_steps(seller_order)
    shipment = seller_order.shipment
    pickup = shipment&.local_pickup?
    current_step = seller_order_fulfillment_current_step(seller_order)

    [
      { label: "Pedido recebido", time: seller_order.order.created_at },
      { label: "Em preparação", time: nil },
      { label: pickup ? "Pronto para retirada" : "Enviado", time: shipment&.shipped_at },
      { label: pickup ? "Retirado" : "Entregue", time: shipment&.delivered_at }
    ].each_with_index.map do |step, index|
      step.merge(state: seller_order_timeline_step_state(index, current_step))
    end
  end

  private

  def seller_order_fulfillment_current_step(seller_order)
    return 0 if seller_order.pending? || seller_order.cancelled? || seller_order.refunded?

    shipment = seller_order.shipment
    return 1 unless shipment
    return 3 if shipment.delivered?
    return 2 if shipment.shipped?

    1
  end

  def seller_order_timeline_step_state(index, current_step)
    return :complete if index < current_step
    return :current if index == current_step

    :upcoming
  end
end
