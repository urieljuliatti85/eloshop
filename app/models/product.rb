class Product < ApplicationRecord
  include MoneyAttribute

  # `stock_quantity` muda a cada compra, dentro do checkout: seria só ruído.
  has_paper_trail ignore: %i[stock_quantity updated_at]

  money_attribute :price
  money_attribute :fixed_shipping
  money_attribute :fixed_shipping_interstate

  class InvalidStatusTransition < StandardError; end

  STANDARD_STATUS_TRANSITIONS = {
    "draft" => %w[active],
    "active" => %w[draft sold_out discontinued],
    "sold_out" => %w[active discontinued],
    "discontinued" => []
  }.freeze

  # Uma peça única, uma vez vendida (sold_out), não pode "voltar" a ficar
  # disponível automaticamente — ver docs/inventory.md, "One of a Kind".
  ONE_OF_A_KIND_STATUS_TRANSITIONS = STANDARD_STATUS_TRANSITIONS.merge(
    "sold_out" => %w[discontinued]
  ).freeze

  MAIN_IMAGE_MAX_BYTES = 5.megabytes
  MAIN_IMAGE_ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  IMAGES_MAX_COUNT = 2

  # Limiar de alerta no dashboard do admin — só para produtos com estoque
  # físico rastreável (availability_type standard); não se aplica a
  # made_to_order (sem estoque físico) nem one_of_a_kind (sempre 1 unidade).
  LOW_STOCK_THRESHOLD = 3

  # Chave do painel do vendedor: desligada, o artesão não cria novas
  # variantes nem campos de personalização (decisão de produto de
  # 2026-11-02). A implementação continua inteira: a loja, o carrinho e o
  # checkout seguem usando o que já existe, e o vendedor ainda edita e
  # remove o que já cadastrou. O admin não é afetado.
  SELLER_VARIANTS_AND_PERSONALIZATION_ENABLED = false

  enum :status, {
    draft: "draft",
    active: "active",
    sold_out: "sold_out",
    discontinued: "discontinued"
  }, default: "draft"

  # "Pequena tiragem" não é um tipo à parte — é um produto standard com
  # stock_quantity > 1. Ver ROADMAP.md, Fase 8.
  enum :availability_type, {
    standard: "standard",
    one_of_a_kind: "one_of_a_kind",
    made_to_order: "made_to_order"
  }, default: "standard", prefix: true

  # Unidade de venda do insumo do distribuidor (ADR 007, Fase 26). A
  # quantidade continua inteira: "2 pacotes", "3 rolos". O que vem em cada
  # unidade ("pacote com 100 g", "rolo de 50 m") vai em `sale_unit_detail`.
  # Nula na peça de ateliê, que se vende por peça.
  enum :sale_unit, {
    unit: "unit",
    pack: "pack",
    meter: "meter",
    kilogram: "kilogram",
    roll: "roll",
    box: "box"
  }, prefix: :sold_by, validate: { allow_nil: true }
  SALE_UNIT_DETAIL_MAX_LENGTH = 60
  # Teto técnico para quantidades do insumo (mínimo e faixas): muito acima de
  # qualquer pedido e longe do limite da coluna inteira, que antes virava
  # erro 500 em vez de mensagem (achado do QA, 2026-11-07). Também é
  # constraint no banco.
  MAX_ORDER_QUANTITY = 100_000

  has_one_attached :main_image

  # Tamanho do card do catálogo (400px) em 2x: a vitrine nunca serve o original
  # da capa, que pode ter alguns megabytes.
  CARD_IMAGE_VARIANT = { resize_to_fill: [ 800, 800 ] }.freeze

  # A capa com os registros de variante, para o card pedir a variante sem uma
  # query por produto. preload, e não with_attached_main_image (que usa
  # includes): ver o comentário em ProductsController#index sobre o JIT.
  scope :preload_main_image, -> { preload(main_image_attachment: { blob: { variant_records: { image_attachment: :blob } } }) }
  # Fotos adicionais (galeria) — main_image continua sendo a capa,
  # explicitamente definida, ver docs/catalog.md "Imagens".
  has_many_attached :images
  has_many :product_variants, dependent: :destroy
  has_many :personalization_options, dependent: :destroy
  has_many :wishlist_items, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :order_items, dependent: :restrict_with_error
  has_many :product_tags, dependent: :destroy
  has_many :tags, through: :product_tags
  has_many :product_materials, dependent: :destroy
  has_many :materials, through: :product_materials
  has_many :product_techniques, dependent: :destroy
  has_many :techniques, through: :product_techniques
  # Faixas de desconto por quantidade, só do insumo (ProductPriceTier).
  has_many :price_tiers, -> { order(:min_quantity) }, class_name: "ProductPriceTier", dependent: :destroy, inverse_of: :product
  # O formulário do painel do distribuidor (Fase 26, PR B) edita as faixas
  # junto com o produto, numa transação só.
  # Linha de faixa deixada em branco no formulário não vira faixa.
  accepts_nested_attributes_for :price_tiers, allow_destroy: true,
    reject_if: ->(attributes) { attributes.slice("min_quantity", "discount_percent", "discount_bps").values.all?(&:blank?) && attributes["id"].blank? }
  belongs_to :seller
  belongs_to :category, optional: true

  before_validation :assign_slug, if: -> { slug.blank? && name.present? }
  before_validation :assign_sku, if: -> { sku.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :seller_id }
  # O SKU é opcional para quem cadastra: em branco, `assign_sku` gera um. A
  # coluna continua NOT NULL porque o OrderItem guarda o SKU como snapshot.
  validates :sku, uniqueness: { scope: :seller_id }
  validates :currency, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  # Vazio não é "não é um número": a pessoa só apagou o valor, e a mensagem
  # diz o que pôr no lugar. Vazio continua sendo erro (não vira 0 sozinho).
  validates :stock_quantity, presence: { message: "precisa ser informado (use 0 se ainda não tiver peças prontas)" }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :weight_grams, :length_cm, :width_cm, :height_cm,
            numericality: { greater_than: 0 }, allow_nil: true
  validates :fixed_shipping_cents, :fixed_shipping_estimated_days,
            presence: true, if: :fixed_shipping_started?
  validates :fixed_shipping_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :fixed_shipping_estimated_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  # Faixa opcional para fora do estado do ateliê; só existe como variação da
  # principal (as mesmas regras também são constraints no banco).
  validates :fixed_shipping_interstate_cents, :fixed_shipping_interstate_estimated_days,
            presence: true, if: :fixed_shipping_interstate_started?
  validates :fixed_shipping_interstate_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :fixed_shipping_interstate_estimated_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :fixed_shipping_interstate_requires_base, if: :fixed_shipping_interstate_started?

  normalizes :sale_unit_detail, with: ->(detail) { detail.squish.presence }
  validates :sale_unit_detail, length: { maximum: SALE_UNIT_DETAIL_MAX_LENGTH }
  validates :min_order_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_ORDER_QUANTITY }
  # Unidade, descrição, mínimo e faixas são do insumo do distribuidor: na peça
  # do ateliê ficam nos padrões neutros (ADR 007). As duas checagens só rodam
  # quando há algo de insumo em jogo, para não pôr consultas em todo `save` de
  # produto (a baixa de estoque do checkout também salva o produto).
  validate :supply_fields_only_for_distributor, if: :supply_fields_filled?
  validate :price_tiers_coherent, if: -> { (price_tiers.target.any? || min_order_quantity_changed?) && supply? }

  # Peso e dimensões são exigidos para PUBLICAR, não para rascunhar: o
  # vendedor cadastra a peça enquanto ainda a está fazendo, mas não anuncia
  # sem saber quanto ela pesa — o frete real cotaria errado, e é o artesão
  # quem absorve a diferença.
  #
  # A regra vive no `publish!`, e não como validação de `active?`: como
  # validação, ela recairia sobre todo `save` de produto publicado —
  # inclusive a baixa de estoque de uma venda, que não tem nada a ver com
  # frete e passaria a falhar em catálogo legado.
  validate :shippable_dimensions_for_publication, on: :publication

  # Categoria é como o cliente encontra a peça (§14): sem ela o produto some
  # dos filtros e das seções da home. Mesma lógica do peso — exigida para
  # publicar, não para rascunhar, e fora do `save` comum para não quebrar o
  # catálogo legado sem categoria.
  validate :category_for_publication, on: :publication

  # O frete é definido pelo vendedor (termos comerciais de 2026-10-03): sem
  # valor próprio, o checkout cairia na tabela interna, um palpite da
  # plataforma que não bate com o custo real da etiqueta. Mesma lógica do
  # peso: exigido só para publicar, para não quebrar o catálogo já publicado.
  validate :seller_defined_shipping_for_publication, on: :publication

  validates :stock_quantity, numericality: { less_than_or_equal_to: 1, message: "deve ser 0 ou 1 numa peça única" },
            allow_nil: true, if: :availability_type_one_of_a_kind?
  validates :production_time_min_days, :production_time_max_days,
            presence: true, numericality: { greater_than: 0 }, if: :availability_type_made_to_order?
  validate :production_time_range_valid, if: :availability_type_made_to_order?

  validate :availability_type_immutable_while_has_variants, if: :availability_type_changed?
  validate :seller_immutable_after_sale, if: :seller_id_changed?

  validate :main_image_content_type_allowed
  validate :main_image_size_within_limit
  validate :images_content_type_allowed
  validate :images_size_within_limit
  validate :images_count_within_limit

  def publish!
    # Status que não publica (descontinuado) recusa por isso, antes do cadastro.
    ensure_transition_allowed!("active")
    blockers = publication_blockers
    raise InvalidStatusTransition, blockers.join(" ") if blockers.any?

    transition_to!("active")
  end

  # Tudo o que impede a publicação, de uma vez — vazio quando pode publicar.
  # É a mesma resposta para o `publish!` e para o aviso "Para publicar, falta"
  # da página do rascunho: o ateliê vê todas as pendências juntas, em vez de
  # descobrir uma por tentativa. Inclui os erros de campo (prazo de produção
  # inválido, frete pela metade), que antes caíam numa mensagem genérica de
  # peso e medidas. Roda as validações, então substitui `errors`.
  def publication_blockers
    blockers = []
    # Cada tipo na própria vitrine (ADR 007): o ateliê na de peças, o
    # distribuidor na de insumos; a regra é a mesma (aprovado ou liberado).
    if supply?
      blockers << "A distribuidora precisa estar aprovada ou liberada na vitrine antes da publicação." unless seller.supply_listed?
    else
      blockers << "O ateliê precisa estar aprovado ou liberado na vitrine antes da publicação." unless seller&.publicly_listed?
    end
    blockers << "Aceite os termos comerciais antes de publicar." unless seller&.terms_accepted?

    valid?(:publication)
    blockers + errors.full_messages.map { |message| message.end_with?(".") ? message : "#{message}." }
  end

  def seller_defined_shipping_for_publication
    return if fixed_shipping_configured? || free_shipping?

    errors.add(:base, "Defina o frete deste produto (valor e prazo) ou marque frete grátis antes de publicar.")
  end

  # Insumo não tem categoria de peça: a vitrine de insumos navega por
  # material e técnica (decisão de 2026-11-07, ADR 007).
  def category_for_publication
    return if supply?

    errors.add(:base, "Escolha uma categoria antes de publicar: é como o cliente encontra o produto.") if category.blank?
  end

  # Sem peso ou dimensões o frete real não cotiza, e o produto não deveria
  # estar anunciado.
  def shippable_dimensions_for_publication
    missing = { weight_grams: "peso", length_cm: "comprimento", width_cm: "largura", height_cm: "altura" }
      .select { |field, _| public_send(field).blank? }
      .values

    return if missing.empty?

    errors.add(:base, "Informe #{missing.to_sentence} antes de publicar: são necessários para calcular o frete.")
  end

  def unpublish!
    transition_to!("draft")
  end

  def discontinue!
    transition_to!("discontinued")
  end

  # Fonte única de verdade sobre disponibilidade de compra — ver docs/inventory.md.
  def available_for_purchase?
    purchase_blocker.nil?
  end

  # Por que o produto não pode ser comprado agora (`nil` quando pode). As telas
  # usam o motivo para escolher a mensagem; a decisão continua sendo uma só.
  # `:seller_not_accepting_orders` é o ateliê que aparece na loja (vitrine do
  # pré-cadastro, ou aprovado que desconectou o Mercado Pago) mas ainda não
  # recebe pagamento: a peça em si está disponível, só não pode ser vendida.
  def purchase_blocker
    return :unavailable unless seller&.publicly_listed?
    return :unavailable unless active?
    return :unavailable if category && !category.visible?
    return :unavailable unless in_stock_for_sale?
    return :below_minimum_stock if below_minimum_stock?
    return :seller_not_accepting_orders unless seller.approved?

    nil
  end

  def has_variants?
    product_variants.any?
  end

  # Nome da unidade para a quantidade dada: "1 pacote", "10 pacotes". Sem
  # unidade definida, "unidade".
  def sale_unit_name(count = 1)
    I18n.t(sale_unit || "unit", scope: "products.sale_units", count: count)
  end

  # Insumo de distribuidor (ADR 007): o que tem unidade, mínimo e faixas.
  def supply?
    seller&.distributor? || false
  end

  # Quanto do produto existe para vender, somando as variantes ativas: a
  # quantidade mínima e a faixa valem para o produto inteiro (5 cores do
  # mesmo fio contam juntas). Sob encomenda não tem estoque físico.
  def stock_for_minimum
    return nil if availability_type_made_to_order?
    return product_variants.select(&:active?).sum(&:stock_quantity) if has_variants?

    stock_quantity
  end

  # Mínimo maior que o estoque: o insumo aparece, mas não dá para comprar a
  # quantidade exigida. É indisponibilidade, decidida aqui, na fonte única.
  def below_minimum_stock?
    available = stock_for_minimum
    min_order_quantity > 1 && !available.nil? && available < min_order_quantity
  end

  # A faixa que vale para a quantidade total do produto no pedido: a de maior
  # mínimo já alcançado, ou nenhuma.
  def price_tier_for(quantity)
    price_tiers.select { |tier| tier.min_quantity <= quantity.to_i }.max_by(&:min_quantity)
  end

  # Preço de uma unidade (da variante, quando houver) com a faixa da
  # quantidade total aplicada, em centavos inteiros. O carrinho e o checkout
  # passam a usar isto na Fase 27.
  def unit_price_for(quantity, unit_price_cents: price_cents)
    tier = price_tier_for(quantity)
    tier ? tier.apply_to(unit_price_cents) : unit_price_cents
  end

  # Sem variante e sem personalização obrigatória — pode ser adicionado ao
  # carrinho diretamente (ex.: "mover para o carrinho" a partir da
  # wishlist), sem precisar passar pela PDP para escolher nada.
  def directly_purchasable?
    !has_variants? && personalization_options.none?(&:required?)
  end

  def approved_reviews
    reviews.visible.order(created_at: :desc)
  end

  # A PDP e o JSON-LD pedem nota e contagem mais de uma vez cada, e cada
  # chamada é uma agregação nova. Medido: das 6 chamadas em uma PDP com
  # avaliações, o query cache do Active Record serve 4 — sobram 2 idas ao
  # banco. Combinar as duas agregações economizaria 1 query ao custo de SQL
  # cru e de uma memoização que envelhece no objeto; não compensa (§3, §51).
  def average_rating
    approved_reviews.average(:rating)&.round(1)
  end

  def reviews_count
    approved_reviews.count
  end

  # Menor preço entre as variantes ativas — usado no catálogo para produtos
  # com variante, já que o price_cents do próprio produto não representa
  # necessariamente nenhuma opção comprável (Fase 9, preço por variante).
  def starting_price_cents
    return price_cents unless has_variants?

    product_variants.select(&:active?).filter_map(&:price_cents).min || price_cents
  end

  # Snapshot textual do prazo de produção, gravado no pedido no momento da
  # compra (ver docs/checkout.md e docs/shipping.md — não confundir com
  # prazo de transporte).
  def production_time_range
    return nil unless availability_type_made_to_order?

    "#{production_time_min_days} a #{production_time_max_days} dias úteis"
  end

  def fixed_shipping_started?
    fixed_shipping_cents.present? || fixed_shipping_estimated_days.present?
  end

  def fixed_shipping_configured?
    fixed_shipping_cents.present? && fixed_shipping_estimated_days.present?
  end

  def fixed_shipping_interstate_started?
    fixed_shipping_interstate_cents.present? || fixed_shipping_interstate_estimated_days.present?
  end

  def fixed_shipping_interstate_configured?
    fixed_shipping_interstate_cents.present? && fixed_shipping_interstate_estimated_days.present?
  end

  scope :matching_query, ->(query) {
    term = "%#{sanitize_sql_like(query.to_s.strip)}%"
    left_joins(:category, :tags, :materials, :techniques)
      .where(
        <<~SQL.squish,
          products.name ILIKE :term OR
          products.description ILIKE :term OR
          categories.name ILIKE :term OR
          tags.name ILIKE :term OR
          materials.name ILIKE :term OR
          techniques.name ILIKE :term
        SQL
        term: term
      )
      .distinct
  }

  # Quando há variantes, o estoque do produto não representa uma quantidade
  # comercial. Cada ProductVariant passa a ser a fonte de verdade; por isso
  # este escopo cobre somente produtos sem variantes.
  scope :without_variants, -> { where.missing(:product_variants) }
  # Sem frete definido pelo vendedor: o checkout usa a tabela interna, um
  # palpite da plataforma. Publicados assim antes da regra de publicação.
  scope :without_seller_defined_shipping, -> { where(fixed_shipping_cents: nil, free_shipping: false) }
  scope :low_stock, -> {
    active.availability_type_standard.without_variants.where(stock_quantity: 1..LOW_STOCK_THRESHOLD)
  }

  scope :publicly_visible, -> { active.joins(:seller).merge(Seller.publicly_listed).in_visible_category }

  # Categoria desabilitada tira do ar os produtos dela e da subárvore abaixo
  # (Category#visible?). Produto sem categoria nunca é escondido por isso:
  # `category_id` é opcional e ausência não é desabilitação.
  scope :in_visible_category, -> {
    hidden = Category.hidden_ids
    hidden.empty? ? all : where(category_id: nil).or(where.not(category_id: hidden))
  }

  # Descontinuado é saída definitiva do catálogo: o produto não pode
  # aparecer em lugar nenhum voltado ao cliente. `publicly_visible` já o
  # exclui por exigir `active`, mas listas que partem de um vínculo do
  # próprio cliente — favoritos, itens de carrinho — não passam por lá.
  # Fonte única para esses casos (§19); nunca espalhar `where.not(status:
  # :discontinued)` pela aplicação.
  scope :not_discontinued, -> { where.not(status: :discontinued) }

  RELATED_PRODUCTS_LIMIT = 4

  # Sem categorias/tags (Fase 11 ainda não implementada) para basear uma
  # recomendação real — decisão do negócio: outros produtos ativos, mais
  # recentes primeiro. Reavaliar quando a Fase 11 existir.
  def related_products(limit: RELATED_PRODUCTS_LIMIT)
    seller.products.publicly_visible.where.not(id: id).order(created_at: :desc).limit(limit)
  end

  # Capa (main_image) primeiro, depois o resto da galeria — main_image
  # continua sendo a foto explicitamente definida como principal, nunca
  # depende da ordem acidental dos anexos (ver docs/catalog.md, "Imagens").
  def gallery_images
    photos = []
    photos << main_image if main_image.attached?
    photos.concat(images.to_a)
    photos
  end

  private

  # Produto sob encomenda não depende de estoque físico. Produto com variantes
  # (Fase 9) nunca é comprado "cru" — a decisão passa sempre pela variante
  # escolhida, então aqui só reflete se existe alguma opção comprável.
  def in_stock_for_sale?
    return product_variants.any?(&:available_for_purchase?) if has_variants?
    return true if availability_type_made_to_order?

    stock_quantity.positive?
  end

  def supply_fields_filled?
    sale_unit.present? || sale_unit_detail.present? || min_order_quantity.to_i > 1
  end

  def supply_fields_only_for_distributor
    return if supply?

    errors.add(:sale_unit, "só existe para insumo de distribuidor") if sale_unit.present?
    errors.add(:sale_unit_detail, "só existe para insumo de distribuidor") if sale_unit_detail.present?
    errors.add(:min_order_quantity, "só pode ser maior que 1 em insumo de distribuidor") if min_order_quantity.to_i > 1
  end

  # As faixas só fazem sentido acima do mínimo (abaixo dele a faixa valeria
  # sempre) e com desconto crescente: quem compra mais nunca paga mais por
  # unidade. Conferido no produto porque envolve as faixas entre si.
  def price_tiers_coherent
    tiers = price_tiers.reject(&:marked_for_destruction?).sort_by { |tier| tier.min_quantity.to_i }
    return if tiers.empty?

    if tiers.size > ProductPriceTier::MAX_PER_PRODUCT
      errors.add(:price_tiers, "podem ser no máximo #{ProductPriceTier::MAX_PER_PRODUCT}")
    end
    if tiers.first.min_quantity.to_i <= min_order_quantity.to_i
      errors.add(:price_tiers, "precisam começar acima da quantidade mínima de compra")
    end
    unless tiers.each_cons(2).all? { |lower, higher| higher.discount_bps.to_i > lower.discount_bps.to_i }
      errors.add(:price_tiers, "precisam ter desconto maior a cada faixa")
    end
  end

  def fixed_shipping_interstate_requires_base
    return if fixed_shipping_configured?

    errors.add(:fixed_shipping, "precisa ser definido para o seu estado antes do frete para outros estados")
  end

  def allowed_status_transitions
    availability_type_one_of_a_kind? ? ONE_OF_A_KIND_STATUS_TRANSITIONS : STANDARD_STATUS_TRANSITIONS
  end

  def transition_to!(new_status)
    ensure_transition_allowed!(new_status)
    update!(status: new_status)
  end

  def ensure_transition_allowed!(new_status)
    return if allowed_status_transitions.fetch(status).include?(new_status)

    raise InvalidStatusTransition, "não é possível transicionar de #{status} para #{new_status}"
  end

  def assign_slug
    self.slug = name.parameterize
  end

  # Prefixo legível (do nome) + sufixo aleatório; o índice único
  # (seller_id, sku) garante que uma colisão rara não passe em silêncio.
  def assign_sku
    self.sku = "#{name.parameterize.upcase.first(20).delete_suffix('-')}-#{SecureRandom.alphanumeric(4).upcase}"
  end

  def production_time_range_valid
    return if production_time_min_days.blank? || production_time_max_days.blank?
    return if production_time_min_days <= production_time_max_days

    errors.add(:production_time_max_days, "deve ser maior ou igual ao prazo mínimo")
  end

  def main_image_content_type_allowed
    return unless main_image.attached?
    return if MAIN_IMAGE_ALLOWED_CONTENT_TYPES.include?(main_image.content_type)

    errors.add(:main_image, "deve ser um arquivo PNG, JPEG ou WEBP")
  end

  def main_image_size_within_limit
    return unless main_image.attached?
    return if main_image.byte_size <= MAIN_IMAGE_MAX_BYTES

    errors.add(:main_image, "deve ter no máximo 5MB")
  end

  def images_content_type_allowed
    return unless images.attached?
    return if images.all? { |image| MAIN_IMAGE_ALLOWED_CONTENT_TYPES.include?(image.content_type) }

    errors.add(:images, "deve conter apenas arquivos PNG, JPEG ou WEBP")
  end

  def images_size_within_limit
    return unless images.attached?
    return if images.all? { |image| image.byte_size <= MAIN_IMAGE_MAX_BYTES }

    errors.add(:images, "cada imagem deve ter no máximo 5MB")
  end

  # Só quando a galeria está recebendo fotos: produtos antigos têm mais fotos
  # do que o limite atual, e a baixa de estoque de uma venda não pode falhar
  # por isso (mesmo raciocínio do `:publication`). Eles seguem como estão até
  # o vendedor tentar acrescentar outra.
  def images_count_within_limit
    return unless attachment_changes["images"]
    return if images.size <= IMAGES_MAX_COUNT

    errors.add(:images, "não pode ter mais de #{IMAGES_MAX_COUNT} imagens")
  end

  def availability_type_immutable_while_has_variants
    return if availability_type_standard?
    return unless persisted? && has_variants?

    errors.add(:availability_type, "não pode ser alterado enquanto o produto tiver variantes cadastradas")
  end

  def seller_immutable_after_sale
    return unless persisted? && order_items.exists?

    errors.add(:seller, "não pode ser alterado depois que o produto participa de um pedido")
  end
end
