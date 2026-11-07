# Caminhos do painel de cada tipo de vendedor (ADR 007): o ateliê em /painel
# (`seller_*`), o distribuidor em /atacado/painel (`distributor_*`). É a fonte
# única para as telas que os dois painéis compartilham (Primeiros passos,
# endereço de origem, guias, chave PIX, avisos) e para os redirecionamentos
# delas: um link fixo em `seller_*_path` levava o distribuidor a /painel, que
# o devolvia ao painel dele, e a jornada quebrava em silêncio (revisão de
# arquitetura de 2026-11-07).
#
#   panel_path(:root)                         → /painel ou /atacado/painel
#   panel_path(:getting_started, etapa: "…")  → seller_getting_started_path(...)
#   panel_path(:mark_as_read_notification, n) → mark_as_read_seller_notification_path(n)
#
# Rota que o painel do distribuidor não tem levanta NoMethodError: falha alto,
# em vez de mandar para o painel errado. A conexão do Mercado Pago fica de
# fora de propósito: o redirect URI registrado no provedor é um só, em
# /painel, e as telas chamam `seller_mercado_pago_*` direto.
module PanelPaths
  extend ActiveSupport::Concern

  # Prefixos de ação que o Rails põe antes do nome do painel
  # (`new_seller_product`, `mark_as_read_seller_notification`).
  ACTION_PREFIXES = %w[mark_as_read_ new_ edit_].freeze

  # A mesma tela com outro nome no painel do distribuidor.
  DISTRIBUTOR_ROUTE_NAMES = {
    "atelier" => "profile",
    "atelier_postal_code" => "profile_postal_code",
    "atelier_postal_codes" => "profile_postal_codes"
  }.freeze

  included do
    helper_method :panel_path, :seller_panel_path_for
  end

  private

  def panel_path(route, *args, seller: nil, **options)
    seller ||= (current_seller if respond_to?(:current_seller, true))
    name = route.to_s
    action = ACTION_PREFIXES.find { |prefix| name.start_with?(prefix) }
    base = action ? name.delete_prefix(action) : name

    if seller&.distributor?
      public_send(:"#{action}distributor_#{DISTRIBUTOR_ROUTE_NAMES.fetch(base, base)}_path", *args, **options)
    else
      public_send(:"#{action}seller_#{base}_path", *args, **options)
    end
  end

  # O início do painel de cada tipo: destino de avisos e redirecionamentos
  # que servem aos dois (a suspensão, o aceite dos termos, o cadastro).
  def seller_panel_path_for(seller)
    panel_path(:root, seller: seller)
  end
end
