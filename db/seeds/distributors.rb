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
    seed_examples
  end

  EXAMPLE_NOTICE = "Exemplo para apresentação da vitrine. Não é um armarinho real: não há compra nem vendedor por trás.".freeze

  # Dados do seed local (db/seeds/armarinhos.rb), sem CPF, responsável ou usuário.
  EXAMPLE_SELLERS = [
    {
      slug: "armarinho-fios-e-cores", name: "Armarinho Fios & Cores", invoice: true,
      supplies: [
        { sku: "SEED-FIO-ALGODAO-001", name: "Fio de algodão macio", description: "Fio versátil para crochê, tricô e peças decorativas.",
          price_cents: 2_490, stock: 80, unit: :pack, unit_detail: "pacote com 400 g", min_quantity: 2,
          materials: [ "Algodão", "Fio" ], techniques: [ "Crochê" ], tier: [ 10, 1_000 ], weight: 400, dimensions: [ 15, 15, 12 ] },
        { sku: "SEED-FIO-MALHA-001", name: "Fio de malha premium", description: "Fio encorpado para cestos, tapetes e macramê.",
          price_cents: 3_990, stock: 45, unit: :roll, unit_detail: "rolo com 1 kg", min_quantity: 1,
          materials: [ "Malha" ], techniques: [ "Macramê" ], tier: [ 8, 800 ], weight: 1_000, dimensions: [ 20, 20, 18 ] }
      ]
    },
    {
      slug: "armarinho-tecidos-e-estampas", name: "Armarinho Tecidos & Estampas", invoice: true,
      supplies: [
        { sku: "SEED-TRICOLINE-FLORAL-001", name: "Tricoline floral", description: "Tecido leve de algodão para costura criativa e patchwork.",
          price_cents: 1_450, stock: 120, unit: :meter, unit_detail: "1,40 m de largura", min_quantity: 2,
          materials: [ "Tecido", "Algodão" ], techniques: [ "Costura", "Bordado" ], tier: [ 10, 1_000 ], weight: 180, dimensions: [ 25, 20, 4 ] },
        { sku: "SEED-FELTRO-001", name: "Feltro colorido", description: "Feltro macio em cores variadas para decoração e artesanato.",
          price_cents: 890, stock: 90, unit: :meter, unit_detail: "1,40 m de largura", min_quantity: 3,
          materials: [ "Feltro" ], techniques: [ "Costura" ], tier: [ 10, 1_200 ], weight: 150, dimensions: [ 24, 18, 3 ] }
      ]
    },
    {
      slug: "armarinho-aviamentos-criativos", name: "Armarinho Aviamentos Criativos", invoice: false,
      supplies: [
        { sku: "SEED-FITA-GORGURAO-001", name: "Fita de gorgurão colorida", description: "Fita firme para laços, embalagens e acabamentos.",
          price_cents: 1_890, stock: 70, unit: :roll, unit_detail: "rolo com 10 m", min_quantity: 2,
          materials: [ "Fita", "Aviamentos" ], techniques: [ "Costura" ], tier: [ 10, 1_000 ], weight: 120, dimensions: [ 12, 12, 6 ] },
        { sku: "SEED-BOTOES-MADEIRA-001", name: "Botões de madeira", description: "Kit de botões lisos para roupas, bolsas e peças artesanais.",
          price_cents: 1_290, stock: 55, unit: :pack, unit_detail: "pacote com 20 unidades", min_quantity: 2,
          materials: [ "Madeira", "Botões" ], techniques: [ "Costura" ], tier: [ 10, 1_000 ], weight: 100, dimensions: [ 10, 8, 3 ] }
      ]
    }
  ].freeze

  def self.seed_examples
    EXAMPLE_SELLERS.each do |attributes|
      seed_example_seller(attributes)
    rescue StandardError => error
      # Em produção, o seed roda a cada boot: um exemplo com erro não pode derrubar
      # o deploy, então o erro vai para o log. Fora de produção, levanta o erro,
      # para que uma falha de seed apareça na hora (foi o que escondeu o bug de
      # publicação dos exemplos).
      Rails.logger.error("distributor_examples_seed_failed slug=#{attributes.fetch(:slug)} error=#{error.class}")
      raise unless Rails.env.production?
    end
  end

  def self.seed_example_seller(attributes)
    seller = Seller.find_or_initialize_by(slug: attributes.fetch(:slug))
    seller.assign_attributes(
      name: attributes.fetch(:name), kind: :distributor, status: :pending,
      showcased_at: seller.showcased_at || Time.current,
      issues_invoices: attributes.fetch(:invoice), notice_text: EXAMPLE_NOTICE
    )
    seller.save!(context: :preview)
    attributes.fetch(:supplies).each { |supply| seed_example_supply(seller, supply) }
  end

  # Insumo publicado (active) mas não comprável: o armarinho segue pending e
  # Product#purchase_blocker recusa a compra (:seller_not_accepting_orders).
  def self.seed_example_supply(seller, attributes)
    product = seller.products.find_or_initialize_by(sku: attributes.fetch(:sku))
    product.assign_attributes(
      name: attributes.fetch(:name), description: attributes.fetch(:description),
      price_cents: attributes.fetch(:price_cents), currency: "BRL", stock_quantity: attributes.fetch(:stock),
      status: (product.status.presence || "draft"), sale_unit: attributes.fetch(:unit),
      sale_unit_detail: attributes.fetch(:unit_detail), min_order_quantity: attributes.fetch(:min_quantity),
      weight_grams: attributes.fetch(:weight), length_cm: attributes.fetch(:dimensions)[0],
      width_cm: attributes.fetch(:dimensions)[1], height_cm: attributes.fetch(:dimensions)[2],
      free_shipping: true
    )
    product.save!
    product.materials = attributes.fetch(:materials).map { |name| Material.find_or_create_by!(name: name) }
    product.techniques = attributes.fetch(:techniques).map { |name| Technique.find_or_create_by!(name: name) }
    min_quantity, discount_bps = attributes.fetch(:tier)
    product.price_tiers.find_or_initialize_by(min_quantity: min_quantity).update!(discount_bps: discount_bps)
    # Publicação de exemplo: não passa por `publish!`, que exige termos aceitos
    # (um vendedor real). O exemplo não é vendido: `purchase_blocker` recusa a
    # compra enquanto o armarinho não estiver aprovado.
    product.update_columns(status: "active", updated_at: Time.current) unless product.active?
    product
  end
  private_class_method :seed_examples, :seed_example_seller, :seed_example_supply

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
