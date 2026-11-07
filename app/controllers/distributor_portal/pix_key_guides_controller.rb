module DistributorPortal
  # A mesma tela do painel do ateliê (SellerPortal::PixKeyGuidesController), no
  # painel do distribuidor: herda a ação e as views, troca a porta, o layout e
  # o tipo aceito (Portal). Revisão de arquitetura de 2026-11-07, opção B.
  class PixKeyGuidesController < SellerPortal::PixKeyGuidesController
    include Portal
  end
end
