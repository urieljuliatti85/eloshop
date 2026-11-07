module DistributorPortalHelper
  # Menu do painel do distribuidor (ADR 007): a mesma lista serve à barra
  # lateral (lg+) e ao painel do hambúrguer, como no painel do ateliê. Só o
  # que o distribuidor já tem: pedidos e mensagens entram com a Fase 27,
  # frete com a 28.
  def distributor_nav_groups
    [
      [ "Operação", [
        [ "Visão geral", distributor_root_path ],
        [ "Avisos", distributor_notifications_path ]
      ] ],
      [ "Catálogo", [
        [ "Insumos", distributor_products_path ],
        [ "Novo insumo", new_distributor_product_path ]
      ] ],
      [ "Configuração", [
        [ "Primeiros passos", distributor_getting_started_path ],
        [ "Dados do armarinho", distributor_profile_path ],
        [ "Conta Vendedor no Mercado Pago", distributor_mercado_pago_guide_path ],
        [ "Cadastro da Chave Pix", distributor_pix_key_guide_path ],
        [ "Termos comerciais", distributor_terms_path ]
      ] ]
    ]
  end

  # A área atual: o item de caminho mais longo que prefixa a URL; a raiz só
  # por igualdade (mesma regra do painel do ateliê).
  def distributor_active_nav_path
    distributor_nav_groups.flat_map(&:last).map(&:last)
      .select { |path| path == distributor_root_path ? request.path == path : request.path.start_with?(path) }
      .max_by(&:length)
  end

  # Abas de baixo do celular (layouts/_seller_mobile_tabs, o mesmo partial do
  # ateliê). Enquanto falta alguma etapa, o início e as três que dependem do
  # distribuidor, cada uma aberta no bloco Primeiros passos do painel inicial,
  # com ✓ ou o ponto da próxima; com o cadastro pronto, o dia a dia.
  def distributor_mobile_tabs(steps)
    slugs = SellerPortal::GettingStartedController::STEP_SLUGS
    next_step = steps.key(false)
    root = distributor_root_path
    step_tab = lambda do |step, label, active|
      { icon: step, label: label, path: distributor_root_path(etapa: slugs[step], anchor: "primeiros-passos"), active: active,
        mark: (steps[step] ? :done : (:next if step == next_step)) }
    end

    if steps.values.include?(false)
      [
        { icon: :home, label: "Início", path: root, active: request.path == root },
        step_tab.call(:address, "Endereço", controller_name == "profiles"),
        step_tab.call(:mercado_pago, "Mercado Pago", controller_name == "mercado_pago_guides"),
        step_tab.call(:pix_key, "PIX", controller_name == "pix_key_guides"),
        step_tab.call(:product, "Insumo", controller_name == "products")
      ]
    else
      [
        { icon: :home, label: "Início", path: root },
        { icon: :products, label: "Insumos", path: distributor_products_path },
        { icon: :new_product, label: "Novo insumo", path: new_distributor_product_path },
        { icon: :notifications, label: "Avisos", path: distributor_notifications_path },
        { icon: :profile, label: "Dados", path: distributor_profile_path }
      ].each { |tab| tab[:active] = tab[:path] == distributor_active_nav_path }
    end
  end
end
