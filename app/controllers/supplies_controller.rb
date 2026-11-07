# Vitrine de insumos (ADR 007, Fase 26, PR C): /insumos e a página de cada
# insumo, em /armarinhos/:slug/insumos/:produto. Só `Product.supply_visible`
# — nunca peça de ateliê, que mora em /produtos — e a navegação é por material
# e técnica (decisão de 2026-11-07). A compra chega na Fase 27: até lá a página
# mostra "Vendas de insumos em breve" no lugar do botão.
class SuppliesController < StorefrontController
  allow_unauthenticated_customer_access

  def index
    @materials = Material.where(id: ProductMaterial.joins(:product).merge(Product.supply_visible).select(:material_id)).order(:name)
    @techniques = Technique.where(id: ProductTechnique.joins(:product).merge(Product.supply_visible).select(:technique_id)).order(:name)
    @material = @materials.find_by(slug: params[:material]) if params[:material].present?
    @technique = @techniques.find_by(slug: params[:tecnica]) if params[:tecnica].present?

    supplies = Product.supply_visible
    supplies = supplies.where(id: ProductMaterial.where(material: @material).select(:product_id)) if @material
    supplies = supplies.where(id: ProductTechnique.where(technique: @technique).select(:product_id)) if @technique
    @supplies = supplies.preload(:seller, :price_tiers, :materials, main_image_attachment: :blob).order(:name)
  end

  def show
    seller = Seller.supply_listed.find_by!(slug: params[:seller_slug])
    @product = seller.products.active.includes(:price_tiers, :materials, :techniques).find_by!(slug: params[:slug])
  end
end
