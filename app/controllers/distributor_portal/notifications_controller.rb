module DistributorPortal
  # A mesma tela do painel do ateliê (SellerPortal::NotificationsController), no
  # painel do distribuidor: herda a ação e as views, troca a porta, o layout e
  # o tipo aceito (Portal). Revisão de arquitetura de 2026-11-07, opção B.
  class NotificationsController < SellerPortal::NotificationsController
    include Portal
  end
end
