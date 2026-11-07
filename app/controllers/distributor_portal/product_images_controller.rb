module DistributorPortal
  # Remover uma foto do insumo: a mesma ação do catálogo do ateliê
  # (SellerPortal::ProductImagesController), escopada a `current_seller`.
  class ProductImagesController < SellerPortal::ProductImagesController
    include Portal
  end
end
