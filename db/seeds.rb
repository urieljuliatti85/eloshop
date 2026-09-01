# frozen_string_literal: true

require "zlib"

# Catálogo inicial (produtos com descrição e imagem). Idempotente: pode ser
# executado de novo sem duplicar SKUs. Em produção só cria o que ainda não
# existe — não sobrescreve preço, estoque nem texto de produtos já cadastrados.
if Rails.env.local?
  User.find_or_create_by!(email_address: "admin@eloshop.test") do |user|
    user.password = "password123"
  end
end

seed_seller = Seller.find_or_create_by!(slug: "eloshop") do |seller|
  seller.name = "EloShop"
  seller.status = "approved"
  seller.approved_at = Time.current
end

def find_or_create_named!(klass, name)
  klass.find_or_create_by!(name: name)
end

def png_gradient(width, height, top_rgb, bottom_rgb)
  raw = +""
  last = [ height - 1, 1 ].max

  height.times do |y|
    t = y.to_f / last
    r = (top_rgb[0] * (1 - t) + bottom_rgb[0] * t).round
    g = (top_rgb[1] * (1 - t) + bottom_rgb[1] * t).round
    b = (top_rgb[2] * (1 - t) + bottom_rgb[2] * t).round
    raw << 0.chr
    raw << ([ r, g, b ] * width).pack("C*")
  end

  deflate = Zlib::Deflate.deflate(raw)

  chunk = lambda do |type, data|
    [ data.bytesize, type, data, Zlib.crc32(type + data) ].pack("NA4A*N")
  end

  png = "\x89PNG\r\n\x1A\n".b
  png << chunk.call("IHDR", [ width, height, 8, 2, 0, 0, 0 ].pack("NNCCCCC"))
  png << chunk.call("IDAT", deflate)
  png << chunk.call("IEND", +"")
  png
end

# Um anexo pode constar no banco sem o arquivo existir no disco. Foi o que
# aconteceu em produção: as imagens foram anexadas enquanto o app ainda
# gravava no filesystem efêmero do container, antes do volume persistente
# entrar. O Postgres é persistente e guardou os registros de blob/attachment;
# o volume ficou vazio. Resultado: toda imagem de produto respondia 404.
#
# Checar só `attached?` fazia o seed pular a reanexação justamente nesse caso,
# então o estado quebrado se reaplicava a cada boot em vez de se curar.
#
# Na dúvida (erro ao consultar o serviço), trata como presente: não vale
# arriscar destruir um anexo bom por causa de uma falha transitória de I/O.
def seed_image_file_missing?(attachment)
  return false unless attachment.attached?

  blobs = attachment.respond_to?(:blobs) ? attachment.blobs : [ attachment.blob ]
  blobs.compact.any? { |blob| !blob.service.exist?(blob.key) }
rescue StandardError
  false
end

# Foto real do catálogo, quando existir. Nem todo produto tem: as imagens vêm
# de bancos com licença aberta (ver db/seeds/images/CREDITS.md) e nem todo item
# encontrou foto adequada. Quem não tem cai no gradiente, que continua servindo
# de placeholder.
#
# Sem constante de propósito: o seed é carregado mais de uma vez no mesmo
# processo (testes, db:seed repetido) e uma constante emitiria warning de
# redefinição a cada carga.
def seed_photo_path(sku)
  path = Rails.root.join("db/seeds/images/#{sku}.jpg")
  path.exist? ? path : nil
end

# Só reconhece como placeholder o que o próprio seed gerou: PNG com exatamente
# o nome que ele usa. Uma foto enviada pelo admin tem outro nome e nunca é
# sobrescrita — o seed roda a cada boot, então trocar imagem alheia por engano
# seria destrutivo e silencioso.
def seed_placeholder_image?(attachment, placeholder_filename)
  blob = attachment.respond_to?(:blobs) ? attachment.blobs.first : attachment.blob
  return false unless blob

  blob.content_type == "image/png" && blob.filename.to_s == placeholder_filename
end

def attach_seed_image(record, attachment_name, filename, top_rgb, bottom_rgb, photo_path = nil)
  attachment = record.public_send(attachment_name)

  if attachment.attached?
    # Reanexa quando o arquivo sumiu, ou quando existe foto real para promover
    # sobre o gradiente que o seed havia colocado.
    stale = seed_image_file_missing?(attachment) ||
            (photo_path.present? && seed_placeholder_image?(attachment, filename))
    return unless stale

    attachment.purge
    # purge apaga o blob no banco, mas a associação segue em cache no objeto
    # em memória. Sem recarregar, o attach seguinte tenta reaproveitar o
    # blob_id recém-apagado e estoura ForeignKeyViolation.
    record.reload
  end

  if photo_path
    record.public_send(attachment_name).attach(
      io: File.open(photo_path, "rb"),
      filename: "#{File.basename(filename, '.*')}.jpg",
      content_type: "image/jpeg"
    )
    return
  end

  io = StringIO.new(png_gradient(640, 640, top_rgb, bottom_rgb))
  io.set_encoding(Encoding::BINARY)
  record.public_send(attachment_name).attach(
    io: io,
    filename: filename,
    content_type: "image/png"
  )
end

casa = find_or_create_named!(Category, "Casa")
decoracao = Category.find_or_create_by!(name: "Decoração", parent: casa)
cozinha = Category.find_or_create_by!(name: "Cozinha", parent: casa)
moda = find_or_create_named!(Category, "Moda")
acessorios = Category.find_or_create_by!(name: "Acessórios", parent: moda)
presentes = find_or_create_named!(Category, "Presentes")

tags = {
  "feito-a-mao" => find_or_create_named!(Tag, "feito-a-mao"),
  "presente" => find_or_create_named!(Tag, "presente"),
  "sustentavel" => find_or_create_named!(Tag, "sustentavel"),
  "minimalista" => find_or_create_named!(Tag, "minimalista"),
  "rustico" => find_or_create_named!(Tag, "rustico"),
  "personalizado" => find_or_create_named!(Tag, "personalizado")
}

materials = {
  "Cerâmica" => find_or_create_named!(Material, "Cerâmica"),
  "Algodão" => find_or_create_named!(Material, "Algodão"),
  "Madeira" => find_or_create_named!(Material, "Madeira"),
  "Vime" => find_or_create_named!(Material, "Vime"),
  "Linho" => find_or_create_named!(Material, "Linho")
}

techniques = {
  "Cerâmica" => find_or_create_named!(Technique, "Cerâmica"),
  "Crochê" => find_or_create_named!(Technique, "Crochê"),
  "Bordado" => find_or_create_named!(Technique, "Bordado"),
  "Marcenaria" => find_or_create_named!(Technique, "Marcenaria"),
  "Macramê" => find_or_create_named!(Technique, "Macramê"),
  "Pintura" => find_or_create_named!(Technique, "Pintura")
}

catalog = [
  {
    sku: "VASO-AZUL-001",
    name: "Vaso artesanal azul",
    description: "Vaso de cerâmica modelado no torno e esmaltado em azul cobalto. " \
                 "Cada peça leva as marcas do processo: pequenas variações de tom e " \
                 "textura que tornam o objeto único. Serve para flores secas ou como " \
                 "peça de destaque na estante.",
    price_cents: 8990,
    stock_quantity: 8,
    availability_type: :standard,
    category: decoracao,
    tag_names: %w[feito-a-mao minimalista],
    material_names: [ "Cerâmica" ],
    technique_names: [ "Cerâmica" ],
    weight_grams: 900,
    length_cm: 14,
    width_cm: 14,
    height_cm: 22,
    colors: [ [ 47, 86, 140 ], [ 196, 214, 232 ] ]
  },
  {
    sku: "CANECA-001",
    name: "Caneca de cerâmica pintada à mão",
    description: "Caneca de cerâmica com 280 ml, pintada à mão em esmalte fosco. " \
                 "A alça é modelada uma a uma para um encaixe confortável. Ideal para " \
                 "o café da manhã ou para presentear.",
    price_cents: 4990,
    stock_quantity: 12,
    availability_type: :standard,
    category: cozinha,
    tag_names: %w[feito-a-mao presente],
    material_names: [ "Cerâmica" ],
    technique_names: [ "Cerâmica", "Pintura" ],
    weight_grams: 380,
    length_cm: 12,
    width_cm: 8,
    height_cm: 9,
    colors: [ [ 184, 92, 56 ], [ 245, 232, 220 ] ]
  },
  {
    sku: "CESTO-VIME-001",
    name: "Cesto de vime trançado",
    description: "Cesto trançado à mão em vime natural, reforçado na base. Serve para " \
                 "organizar mantas, brinquedos ou como cachepô. O tom do vime varia " \
                 "conforme a safra — cada cesto é um pouco diferente.",
    price_cents: 12990,
    stock_quantity: 5,
    availability_type: :standard,
    category: decoracao,
    tag_names: %w[feito-a-mao rustico sustentavel],
    material_names: [ "Vime" ],
    technique_names: [],
    weight_grams: 650,
    length_cm: 35,
    width_cm: 28,
    height_cm: 24,
    colors: [ [ 166, 124, 82 ], [ 232, 214, 186 ] ]
  },
  {
    sku: "BOWL-ENCOMENDA-001",
    name: "Bowl de cerâmica sob encomenda",
    description: "Bowl raso de cerâmica, feito sob encomenda no torno. Você escolhe o " \
                 "tamanho aproximado; a peça é produzida depois da compra, com o prazo " \
                 "informado no pedido. Esmalte em tons terrosos, interior claro.",
    price_cents: 7900,
    stock_quantity: 0,
    availability_type: :made_to_order,
    production_time_min_days: 7,
    production_time_max_days: 12,
    category: cozinha,
    tag_names: %w[feito-a-mao],
    material_names: [ "Cerâmica" ],
    technique_names: [ "Cerâmica" ],
    weight_grams: 520,
    length_cm: 18,
    width_cm: 18,
    height_cm: 6,
    colors: [ [ 140, 98, 72 ], [ 236, 224, 208 ] ]
  },
  {
    sku: "COLAR-MACRAME-001",
    name: "Colar de macramê com pedra bruta",
    description: "Peça única: colar em macramê de algodão cru com uma pedra bruta " \
                 "central. O nó e o comprimento foram pensados para uso diário. Depois " \
                 "desta venda, esta combinação não se repete.",
    price_cents: 15900,
    stock_quantity: 1,
    availability_type: :one_of_a_kind,
    category: acessorios,
    tag_names: %w[feito-a-mao presente],
    material_names: [ "Algodão" ],
    technique_names: [ "Macramê" ],
    weight_grams: 45,
    length_cm: 12,
    width_cm: 8,
    height_cm: 2,
    colors: [ [ 72, 64, 56 ], [ 210, 198, 180 ] ]
  },
  {
    sku: "CAMISETA-001",
    name: "Camiseta artesanal de algodão",
    description: "Camiseta de malha de algodão, tingida em pequeno lote. Modelagem " \
                 "leve, costura aparente. Disponível em tamanhos P, M e G — cada " \
                 "tamanho é uma variante com estoque próprio.",
    price_cents: 8900,
    stock_quantity: 0,
    availability_type: :standard,
    category: moda,
    tag_names: %w[feito-a-mao sustentavel],
    material_names: [ "Algodão" ],
    technique_names: [],
    weight_grams: 180,
    length_cm: 30,
    width_cm: 22,
    height_cm: 3,
    colors: [ [ 56, 92, 84 ], [ 200, 216, 208 ] ],
    variants: [
      { sku: "CAMISETA-001-P", size: "P", price_cents: 8900, stock_quantity: 4 },
      { sku: "CAMISETA-001-M", size: "M", price_cents: 8900, stock_quantity: 6 },
      { sku: "CAMISETA-001-G", size: "G", price_cents: 9400, stock_quantity: 3 }
    ]
  },
  {
    sku: "TABUA-MADEIRA-001",
    name: "Tábua de corte de madeira",
    description: "Tábua de servir e cortar, feita em marcenaria a partir de madeira " \
                 "de demolição. Acabamento com óleo mineral próprio para alimentos. " \
                 "Pode ir à mesa como petisqueira.",
    price_cents: 11900,
    stock_quantity: 6,
    availability_type: :standard,
    category: cozinha,
    tag_names: %w[feito-a-mao rustico sustentavel],
    material_names: [ "Madeira" ],
    technique_names: [ "Marcenaria" ],
    weight_grams: 1100,
    length_cm: 40,
    width_cm: 22,
    height_cm: 3,
    colors: [ [ 120, 72, 40 ], [ 212, 176, 128 ] ]
  },
  {
    sku: "ALMOFADA-BORDADO-001",
    name: "Almofada bordada com nome",
    description: "Capa de almofada em linho cru com bordado à mão. Informe o nome ou " \
                 "a palavra curta que deve aparecer no bordado — a escolha fica " \
                 "registrada no pedido. Enchimento não incluso.",
    price_cents: 9900,
    stock_quantity: 7,
    availability_type: :standard,
    category: presentes,
    tag_names: %w[feito-a-mao presente personalizado],
    material_names: [ "Linho" ],
    technique_names: [ "Bordado" ],
    weight_grams: 220,
    length_cm: 45,
    width_cm: 45,
    height_cm: 4,
    colors: [ [ 232, 220, 204 ], [ 168, 72, 88 ] ],
    personalizations: [
      { label: "Nome bordado", max_length: 16, required: true }
    ]
  },
  {
    sku: "JOGO-CROCHE-001",
    name: "Jogo americano de crochê",
    description: "Conjunto com dois jogos americanos em crochê de algodão, ponto " \
                 "firme e borda trabalhada. Pequena tiragem: quando o estoque acabar, " \
                 "a peça fica indisponível até um novo lote.",
    price_cents: 6900,
    stock_quantity: 4,
    availability_type: :standard,
    category: cozinha,
    tag_names: %w[feito-a-mao rustico],
    material_names: [ "Algodão" ],
    technique_names: [ "Crochê" ],
    weight_grams: 180,
    length_cm: 40,
    width_cm: 30,
    height_cm: 1,
    colors: [ [ 236, 228, 216 ], [ 176, 140, 108 ] ]
  },
  {
    sku: "LUMINARIA-CERAMICA-001",
    name: "Luminária de mesa em cerâmica",
    description: "Base de luminária em cerâmica esmaltada, feita sob encomenda. O " \
                 "cúpula de linho é costurada à parte. Não inclui lâmpada. Prazo de " \
                 "produção informado no checkout; o transporte é calculado depois.",
    price_cents: 24900,
    stock_quantity: 0,
    availability_type: :made_to_order,
    production_time_min_days: 10,
    production_time_max_days: 18,
    category: decoracao,
    tag_names: %w[feito-a-mao minimalista],
    material_names: [ "Cerâmica", "Linho" ],
    technique_names: [ "Cerâmica" ],
    weight_grams: 1600,
    length_cm: 18,
    width_cm: 18,
    height_cm: 38,
    colors: [ [ 88, 84, 80 ], [ 228, 220, 208 ] ]
  }
]

catalog.each do |item|
  product = seed_seller.products.find_or_initialize_by(sku: item[:sku])
  seed_existing_record = !product.new_record?

  # Em produção, um seed repetido não pode repor estoque nem preço de peça
  # que já está à venda. Em local, reaplicar o seed atualiza o catálogo de
  # desenvolvimento.
  unless seed_existing_record && Rails.env.production?
    product.assign_attributes(
      name: item[:name],
      description: item[:description],
      price_cents: item[:price_cents],
      currency: "BRL",
      stock_quantity: item[:stock_quantity],
      status: "active",
      availability_type: item[:availability_type],
      production_time_min_days: item[:production_time_min_days],
      production_time_max_days: item[:production_time_max_days],
      category: item[:category],
      weight_grams: item[:weight_grams],
      length_cm: item[:length_cm],
      width_cm: item[:width_cm],
      height_cm: item[:height_cm]
    )
    product.save!

    product.tags = item[:tag_names].map { |name| tags.fetch(name) }
    product.materials = item[:material_names].map { |name| materials.fetch(name) }
    product.techniques = item[:technique_names].map { |name| techniques.fetch(name) }

    Array(item[:variants]).each do |variant_attrs|
      variant = product.product_variants.find_or_initialize_by(sku: variant_attrs[:sku])
      variant.assign_attributes(
        size: variant_attrs[:size],
        color: variant_attrs[:color],
        material: variant_attrs[:material],
        price_cents: variant_attrs[:price_cents],
        stock_quantity: variant_attrs[:stock_quantity],
        active: true
      )
      variant.save!
    end

    Array(item[:personalizations]).each do |option_attrs|
      option = product.personalization_options.find_or_initialize_by(label: option_attrs[:label])
      option.assign_attributes(
        max_length: option_attrs[:max_length],
        required: option_attrs[:required]
      )
      option.save!
    end
  end

  top, bottom = item[:colors]
  # A capa usa a foto real quando o produto tem uma; a galeria segue no
  # gradiente, já que só há uma foto por SKU.
  attach_seed_image(product, :main_image, "#{product.slug}.png", top, bottom, seed_photo_path(item[:sku]))
  # Sem guard de `attached?` aqui: attach_seed_image já decide sozinho entre
  # não fazer nada, curar um anexo órfão ou anexar pela primeira vez. O guard
  # anterior impedia a cura da galeria.
  attach_seed_image(product, :images, "#{product.slug}-detalhe.png", bottom, top)
end
