# Dados locais de demonstração para a vitrine de insumos.
# O seed principal e o entrypoint de produção não carregam este arquivo; a
# guarda também torna um `load` acidental em produção um no-op.
return unless Rails.env.local?

module LocalArmarinhosSeed
  def self.sellers
    [
    {
      slug: "armarinho-fios-e-cores",
      name: "Armarinho Fios & Cores",
      owner: "Ana de Souza",
      cpf_key: "fios-e-cores",
      invoice: true,
      email: "fios@armarinhos.eloshop.test",
      supplies: [
        {
          sku: "SEED-FIO-ALGODAO-001", name: "Fio de algodão macio", description: "Fio versátil para crochê, tricô e peças decorativas.",
          price_cents: 2_490, stock: 80, unit: :pack, unit_detail: "pacote com 400 g", min_quantity: 2,
          material_names: [ "Algodão", "Fio" ], technique_names: [ "Crochê" ], tier: [ 10, 1_000 ],
          weight: 400, dimensions: [ 15, 15, 12 ]
        },
        {
          sku: "SEED-FIO-MALHA-001", name: "Fio de malha premium", description: "Fio encorpado para cestos, tapetes e macramê.",
          price_cents: 3_990, stock: 45, unit: :roll, unit_detail: "rolo com 1 kg", min_quantity: 1,
          material_names: [ "Malha" ], technique_names: [ "Macramê" ], tier: [ 8, 800 ],
          weight: 1_000, dimensions: [ 20, 20, 18 ]
        }
      ]
    },
    {
      slug: "armarinho-tecidos-e-estampas",
      name: "Armarinho Tecidos & Estampas",
      owner: "Beatriz Lima",
      cpf_key: "tecidos-e-estampas",
      invoice: true,
      email: "tecidos@armarinhos.eloshop.test",
      supplies: [
        {
          sku: "SEED-TRICOLINE-FLORAL-001", name: "Tricoline floral", description: "Tecido leve de algodão para costura criativa e patchwork.",
          price_cents: 1_450, stock: 120, unit: :meter, unit_detail: "1,40 m de largura", min_quantity: 2,
          material_names: [ "Tecido", "Algodão" ], technique_names: [ "Costura", "Bordado" ], tier: [ 10, 1_000 ],
          weight: 180, dimensions: [ 25, 20, 4 ]
        },
        {
          sku: "SEED-FELTRO-001", name: "Feltro colorido", description: "Feltro macio em cores variadas para decoração e artesanato.",
          price_cents: 890, stock: 90, unit: :meter, unit_detail: "1,40 m de largura", min_quantity: 3,
          material_names: [ "Feltro" ], technique_names: [ "Costura" ], tier: [ 10, 1_200 ],
          weight: 150, dimensions: [ 24, 18, 3 ]
        }
      ]
    },
    {
      slug: "armarinho-aviamentos-criativos",
      name: "Armarinho Aviamentos Criativos",
      owner: "Carla Mendes",
      cpf_key: "aviamentos-criativos",
      invoice: false,
      email: "aviamentos@armarinhos.eloshop.test",
      supplies: [
        {
          sku: "SEED-FITA-GORGURAO-001", name: "Fita de gorgurão colorida", description: "Fita firme para laços, embalagens e acabamentos.",
          price_cents: 1_890, stock: 70, unit: :roll, unit_detail: "rolo com 10 m", min_quantity: 2,
          material_names: [ "Fita", "Aviamentos" ], technique_names: [ "Costura" ], tier: [ 10, 1_000 ],
          weight: 120, dimensions: [ 12, 12, 6 ]
        },
        {
          sku: "SEED-BOTOES-MADEIRA-001", name: "Botões de madeira", description: "Kit de botões lisos para roupas, bolsas e peças artesanais.",
          price_cents: 1_290, stock: 55, unit: :pack, unit_detail: "pacote com 20 unidades", min_quantity: 2,
          material_names: [ "Madeira", "Botões" ], technique_names: [ "Costura" ], tier: [ 10, 1_000 ],
          weight: 100, dimensions: [ 10, 8, 3 ]
        }
      ]
    }
    ]
  end

  def self.run
    sellers.each { |attributes| seed_seller(attributes) }
  end

  def self.seed_seller(attributes)
    seller = Seller.find_or_initialize_by(slug: attributes.fetch(:slug))
    seller.assign_attributes(
      name: attributes.fetch(:name), owner_full_name: attributes.fetch(:owner), kind: :distributor,
      status: :approved, approved_at: seller.approved_at || Time.current,
      showcased_at: seller.showcased_at || Time.current, issues_invoices: attributes.fetch(:invoice)
    )
    seller.cpf = cpf_for(attributes.fetch(:cpf_key)) if seller.new_record? || seller.cpf.blank?
    seller.save!

    user = User.find_or_initialize_by(email_address: attributes.fetch(:email))
    user.assign_attributes(password: "password123", role: :seller, seller: seller)
    user.save!
    SellerTermsAcceptance.record!(user: user, seller: seller, request: ActionDispatch::TestRequest.create)

    attributes.fetch(:supplies).each { |supply| seed_supply(seller, supply) }
  end

  def self.seed_supply(seller, attributes)
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
    product.materials = attributes.fetch(:material_names).map { |name| Material.find_or_create_by!(name: name) }
    product.techniques = attributes.fetch(:technique_names).map { |name| Technique.find_or_create_by!(name: name) }

    min_quantity, discount_bps = attributes.fetch(:tier)
    tier = product.price_tiers.find_or_initialize_by(min_quantity: min_quantity)
    tier.update!(discount_bps: discount_bps)
    product.publish! if product.draft?
    product
  end

  # Gera CPFs válidos e estáveis a partir de uma chave de demonstração, sem
  # guardar documentos reais no seed local.
  def self.cpf_for(key)
    base = format("%09d", Zlib.crc32(key) % 1_000_000_000)
    base = "123456789" if base.chars.uniq.one?
    digits = base.chars.map(&:to_i)
    [ 10, 11 ].each do |weight_start|
      remainder = (digits.each_with_index.sum { |digit, index| digit * (weight_start - index) } * 10) % 11
      digits << (remainder == 10 ? 0 : remainder)
    end
    digits.join
  end
end

LocalArmarinhosSeed.run
