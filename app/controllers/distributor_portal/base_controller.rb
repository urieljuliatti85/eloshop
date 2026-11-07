module DistributorPortal
  # Painel do distribuidor de insumos (ADR 007), em /atacado/painel. Herda a
  # base do painel do ateliê (sessão, termos do próprio tipo, PaperTrail,
  # Primeiros passos) e troca a porta, o layout e o tipo aceito (`Portal`).
  # `current_seller` é `Current.user.seller` e nada mais: nenhuma ação aceita
  # `seller_id` vindo da URL.
  class BaseController < SellerPortal::BaseController
    include Portal
  end
end
