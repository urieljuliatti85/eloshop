module DistributorPortal
  # Catálogo de insumos do distribuidor (ADR 007, Fase 26, PR B). As ações são
  # as do catálogo do ateliê (SellerPortal::ProductsController, por subclasse
  # — revisão de arquitetura de 2026-11-07, opção B): lista, cadastro,
  # edição, fotos otimizadas e com limite, publicar, despublicar e
  # descontinuar. Mudam os campos aceitos e as telas: insumo tem unidade de
  # venda, quantidade mínima, faixas de desconto e material/técnica, e não tem
  # categoria de peça, peça única, sob encomenda nem personalização. O escopo é
  # sempre `current_seller.products`.
  class ProductsController < SellerPortal::ProductsController
    include Portal

    skip_before_action :set_category_tree

    def index
      @products = current_seller.products.preload(:price_tiers, :materials, :techniques, main_image_attachment: :blob).order(created_at: :desc)
      @products = @products.matching_query(params[:q]) if params[:q].present?
    end

    def new
      @product = current_seller.products.new(sale_unit: "unit")
    end

    private

    # Sem `availability_type` (insumo é estoque padrão), prazo de produção,
    # categoria nem retirada: cada um é da peça artesanal. As faixas vêm em
    # porcentagem (`discount_percent`) e são gravadas em basis points.
    def product_params
      params.expect(product: [
        :name, :description, :price, :currency, :sku, :stock_quantity, :main_image,
        :sale_unit, :sale_unit_detail, :min_order_quantity,
        :weight_grams, :length_cm, :width_cm, :height_cm,
        :fixed_shipping, :fixed_shipping_estimated_days, :fixed_shipping_interstate, :fixed_shipping_interstate_estimated_days, :free_shipping,
        material_ids: [], technique_ids: [], images: [],
        price_tiers_attributes: [ [ :id, :min_quantity, :discount_percent, :_destroy ] ]
      ]).except(:images)
    end
  end
end
