# Navegação da área do cliente (/minha-conta e o que pertence à conta), na
# mesma estrutura do admin e nas cores da loja: lateral no desktop
# (layouts/_account_sidebar) e abas no rodapé do celular
# (layouts/_account_mobile_tabs), com o resto num "Mais".
module AccountHelper
  # Áreas que viram abas no rodapé do celular; as demais vão para o "Mais".
  ACCOUNT_TAB_KEYS = %i[home orders wishlist notifications].freeze

  # Fonte única das áreas da conta. `controllers` decide a área ativa.
  def account_nav_items
    [
      { key: :home, label: "Início", path: account_root_path, icon: :home, controllers: %w[accounts] },
      { key: :orders, label: "Pedidos", path: orders_path, icon: :orders, controllers: %w[orders order_messages] },
      { key: :wishlist, label: "Favoritos", path: wishlist_path, icon: :heart, controllers: %w[wishlists] },
      { key: :notifications, label: "Notificações", path: notifications_path, icon: :bell, controllers: %w[notifications],
        count: customer_unread_notifications_count },
      { key: :addresses, label: "Endereços", path: addresses_path, icon: :pin, controllers: %w[addresses] },
      { key: :profile, label: "Cadastro", path: edit_account_profile_path, icon: :user, controllers: %w[account_profiles] }
    ]
  end

  def account_nav_active?(item)
    item[:controllers].include?(controller_name)
  end

  # Uma contagem por requisição: o cabeçalho da loja e as abas da conta
  # mostram o mesmo número.
  def customer_unread_notifications_count
    @customer_unread_notifications_count ||= Current.customer.notifications.unread.count
  end

  def account_icon(name, class_name: "size-5")
    paths = case name
    when :home then [ tag.path(d: "M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-4.5v-6h-5v6H5a1 1 0 0 1-1-1z") ]
    when :orders then [ tag.path(d: "M4 8 12 4l8 4v8l-8 4-8-4z"), tag.path(d: "m4 8 8 4 8-4"), tag.path(d: "M12 12v8") ]
    when :heart then [ tag.path(d: "M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10Z") ]
    when :bell then [ tag.path(d: "M6 8a6 6 0 1 1 12 0c0 4 1.5 5.5 1.5 5.5h-15S6 12 6 8Z"), tag.path(d: "M9.5 16a2.5 2.5 0 0 0 5 0") ]
    when :pin then [ tag.path(d: "M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"), tag.circle(cx: "12", cy: "9.5", r: "2.5") ]
    when :user then [ tag.circle(cx: "12", cy: "8", r: "4"), tag.path(d: "M4 21a8 8 0 0 1 16 0") ]
    when :menu then [ tag.path(d: "M4 7h16M4 12h16M4 17h16") ]
    when :logout then [ tag.path(d: "M10 17l5-5-5-5M15 12H3"), tag.path(d: "M14 3h5a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-5") ]
    else [ tag.circle(cx: "12", cy: "12", r: "9") ]
    end

    tag.svg(safe_join(paths), class: class_name, viewBox: "0 0 24 24", fill: "none",
      stroke: "currentColor", stroke_width: "1.8", stroke_linecap: "round",
      stroke_linejoin: "round", aria: { hidden: true })
  end
end
