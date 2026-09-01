module AdminHelper
  ADMIN_STATUS_LABELS = {
    "pending" => "Pendente", "confirmed" => "Confirmado", "processing" => "Em produção",
    "ready_to_ship" => "Pronto para envio", "shipped" => "Enviado", "delivered" => "Entregue",
    "cancelled" => "Cancelado", "refunded" => "Reembolsado", "paid" => "Pago",
    "authorized" => "Autorizado", "failed" => "Falhou", "active" => "Ativo",
    "inactive" => "Inativo", "draft" => "Rascunho", "sold_out" => "Esgotado",
    "discontinued" => "Descontinuado", "approved" => "Aprovada", "rejected" => "Rejeitada"
  }.freeze

  ADMIN_STATUS_TONES = {
    "pending" => "admin-badge--warning", "authorized" => "admin-badge--warning",
    "draft" => "admin-badge--neutral", "confirmed" => "admin-badge--success",
    "paid" => "admin-badge--success", "delivered" => "admin-badge--success",
    "active" => "admin-badge--success", "approved" => "admin-badge--success",
    "processing" => "admin-badge--info", "ready_to_ship" => "admin-badge--info",
    "shipped" => "admin-badge--info", "cancelled" => "admin-badge--danger",
    "refunded" => "admin-badge--danger", "failed" => "admin-badge--danger",
    "sold_out" => "admin-badge--danger", "discontinued" => "admin-badge--danger",
    "rejected" => "admin-badge--danger", "inactive" => "admin-badge--neutral"
  }.freeze

  def admin_nav_link(label, path, icon:, controllers:)
    active = Array(controllers).include?(controller_name)
    classes = [ "admin-nav-link", ("admin-nav-link--active" if active) ].compact.join(" ")

    link_to path, class: classes, aria: { current: ("page" if active) } do
      safe_join([ admin_icon(icon), tag.span(label) ])
    end
  end

  def admin_status_badge(status, label: nil)
    value = status.to_s
    text = label || ADMIN_STATUS_LABELS.fetch(value, value.humanize)
    tag.span(text, class: "admin-badge #{ADMIN_STATUS_TONES.fetch(value, 'admin-badge--neutral')}")
  end

  def admin_icon(name, class_name: "size-5")
    paths = case name.to_sym
    when :dashboard
      [ tag.path(d: "M4 13h6V4H4v9Zm10 7h6v-9h-6v9ZM4 20h6v-3H4v3Zm10-13h6V4h-6v3Z") ]
    when :products
      [ tag.path(d: "m12 3 8 4.5v9L12 21l-8-4.5v-9L12 3Z"), tag.path(d: "m4.5 7.8 7.5 4.3 7.5-4.3M12 12v9") ]
    when :orders
      [ tag.path(d: "M6 3h12a2 2 0 0 1 2 2v16l-3-2-3 2-3-2-3 2-3-2 3-2V5a2 2 0 0 1 2-2Z"), tag.path(d: "M8 8h8M8 12h8M8 16h5") ]
    when :customers
      [ tag.path(d: "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"), tag.circle(cx: "9", cy: "7", r: "4"), tag.path(d: "M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75") ]
    when :categories
      [ tag.rect(x: "3", y: "3", width: "7", height: "7", rx: "1"), tag.rect(x: "14", y: "3", width: "7", height: "7", rx: "1"), tag.rect(x: "3", y: "14", width: "7", height: "7", rx: "1"), tag.rect(x: "14", y: "14", width: "7", height: "7", rx: "1") ]
    when :coupons
      [ tag.path(d: "M21 12a3 3 0 0 0-3-3V4H6v5a3 3 0 0 0 0 6v5h12v-5a3 3 0 0 0 3-3Z"), tag.path(d: "M9 9h.01M15 15h.01M15 9l-6 6") ]
    when :reviews
      [ tag.path(d: "m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-3-5.6 3 1.1-6.2L3 9.6l6.2-.9L12 3Z") ]
    when :logout
      [ tag.path(d: "M10 17l5-5-5-5M15 12H3"), tag.path(d: "M14 3h5a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-5") ]
    when :store
      [ tag.path(d: "M3 9l2-5h14l2 5"), tag.path(d: "M5 13v8h14v-8M9 21v-6h6v6"), tag.path(d: "M3 9a3 3 0 0 0 6 0 3 3 0 0 0 6 0 3 3 0 0 0 6 0") ]
    else
      [ tag.circle(cx: "12", cy: "12", r: "9") ]
    end

    tag.svg(safe_join(paths), class: class_name, viewBox: "0 0 24 24", fill: "none",
      stroke: "currentColor", stroke_width: "1.8", stroke_linecap: "round",
      stroke_linejoin: "round", aria: { hidden: true })
  end
end
