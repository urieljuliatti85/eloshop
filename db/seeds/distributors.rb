# Seed aditivo para a vitrine de insumos. É carregado no boot da produção e
# pelo seed local, mas nunca cria usuário, documento, aceite de termos ou item
# comprável. O armarinho pendente e liberado é apenas uma prévia visual.
module DistributorCatalogSeed
  # As categorias de insumo são Material, com ícone próprio; também incluímos
  # os nomes concretos usados pelo catálogo local de demonstração.
  MATERIALS = {
    "Fios & Lãs" => :yarn,
    "Tecidos & Mantas" => :fabric,
    "Fitas & Rendas" => :ribbon,
    "Aviamentos & Botões" => :notions,
    "Macramê & Malha" => :yarn,
    "Bijoux & Peças" => :notions,
    "Argila & Cerâmica" => :clay,
    "Tintas & Pincéis" => :other,
    "Madeira & Vime" => :wood,
    "Embalagens" => :other,
    "Algodão" => :yarn,
    "Fio" => :yarn,
    "Linho" => :fabric,
    "Tecido" => :fabric,
    "Malha" => :fabric,
    "Manta Acrílica" => :fabric,
    "Feltro" => :fabric,
    "Fita" => :ribbon,
    "Renda" => :ribbon,
    "Aviamentos" => :notions,
    "Botões" => :notions,
    "Miçangas" => :notions,
    "Madeira" => :wood,
    "Vime" => :wood,
    "Argila" => :clay,
    "Cerâmica" => :clay
  }.freeze unless const_defined?(:MATERIALS, false)

  TECHNIQUES = {
    "Cerâmica" => :clay,
    "Crochê" => :yarn,
    "Tricô" => :yarn,
    "Bordado" => :needlework,
    "Costura" => :needlework,
    "Marcenaria" => :wood,
    "Macramê" => :knotting,
    "Pintura" => :paint,
    "Patchwork" => :fabric,
    "Amigurumi" => :yarn,
    "Encadernação" => :other
  }.freeze unless const_defined?(:TECHNIQUES, false)

  def self.call
    seed_taxonomy(Material, MATERIALS)
    seed_taxonomy(Technique, TECHNIQUES)
    seed_preview_distributor
  end

  def self.seed_taxonomy(model, entries)
    entries.each do |name, icon_type|
      record = model.find_or_create_by!(name: name) do |new_record|
        new_record.icon_type = icon_type
      end

      # Registros criados antes dos ícones recebem `other` pela migration.
      # Preenchemos esse placeholder uma vez, sem sobrescrever escolha manual.
      record.update!(icon_type: icon_type) if icon_type != :other && record.icon_type == "other"
    end
  end
  private_class_method :seed_taxonomy

  def self.seed_preview_distributor
    existing = Seller.find_by(slug: Seller::PREVIEW_DISTRIBUTOR_SLUG)
    return existing if existing&.distributor?
    return if existing

    Seller.new(
      name: "Prévia de Armarinho EloShop",
      slug: Seller::PREVIEW_DISTRIBUTOR_SLUG,
      kind: :distributor,
      status: :pending,
      showcased_at: Time.current,
      notice_text: "Prévia demonstrativa do pré-cadastro de armarinhos."
    ).save!(context: :preview)
  end
  private_class_method :seed_preview_distributor
end

DistributorCatalogSeed.call
