class Seller < ApplicationRecord
  # Lista permitida (`only`), nunca `ignore`: a tabela tem tokens cifrados, CPF e
  # endereço, que não podem ir parar em `versions` se alguém criar uma coluna nova.
  has_paper_trail only: %i[name slug status approved_at showcased_at hidden_at mercado_pago_user_id mercado_pago_connected_at mercado_pago_live_mode]

  class VerificationRequired < StandardError; end

  enum :status, {
    pending: "pending",
    approved: "approved",
    suspended: "suspended"
  }, default: "pending"

  ORIGIN_ADDRESS_FIELDS = %i[
    origin_zip_code origin_street origin_number origin_neighborhood origin_city origin_state
  ].freeze

  # Tema da vitrine pública: logo, capa e uma mensagem de rodapé. Tudo
  # opcional — sem capa a vitrine usa a foto da peça mais recente.
  THEME_IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  THEME_IMAGE_MAX_BYTES = 5.megabytes
  FOOTER_TEXT_MAX_LENGTH = 300
  ABOUT_TEXT_MAX_LENGTH = 1000
  NOTICE_TEXT_MAX_LENGTH = 140

  # Opções visuais (paleta, fonte, layout, topo, fundo...): chaves de SellerTheme.
  validates :theme_palette, inclusion: { in: SellerTheme::PALETTES.keys }
  validates :theme_font, inclusion: { in: SellerTheme::FONTS.keys }
  validates :theme_layout, inclusion: { in: SellerTheme::LAYOUTS.keys }
  validates :theme_hero, inclusion: { in: SellerTheme::HEROES.keys }
  validates :theme_corners, inclusion: { in: SellerTheme::CORNERS.keys }
  validates :theme_card_style, inclusion: { in: SellerTheme::CARD_STYLES.keys }
  validates :theme_background, inclusion: { in: SellerTheme::BACKGROUNDS.keys }
  validates :theme_ornament, inclusion: { in: SellerTheme::ORNAMENTS.keys }
  validates :theme_image_ratio, inclusion: { in: SellerTheme::IMAGE_RATIOS.keys }
  validates :theme_heading_font, inclusion: { in: SellerTheme::HEADING_FONTS.keys }
  validate :theme_accent_color_readable
  validates :theme_sections, presence: true
  validate :theme_sections_known
  validates :about_text, length: { maximum: ABOUT_TEXT_MAX_LENGTH }
  validates :notice_text, length: { maximum: NOTICE_TEXT_MAX_LENGTH }
  validates :instagram_handle, format: { with: /\A[A-Za-z0-9._]{1,30}\z/, message: "é inválido" }, allow_nil: true
  validates :whatsapp_number, format: { with: /\A\d{10,13}\z/, message: "deve ter DDD e número (10 a 13 dígitos)" }, allow_nil: true
  before_validation :ensure_catalog_section

  has_one_attached :logo
  has_one_attached :cover_image
  has_one_attached :about_image

  has_many :users, dependent: :restrict_with_error
  has_many :seller_terms_acceptances, dependent: :restrict_with_error
  has_many :products, dependent: :restrict_with_error
  has_many :seller_orders, dependent: :restrict_with_error
  has_many :seller_reports, dependent: :destroy
  has_many :fraud_alerts, dependent: :destroy
  has_many :notifications, as: :recipient, dependent: :destroy

  # Ids de vendedores com uma aceitação registrada para a versão vigente dos
  # termos (`terms_accepted?` faz a mesma pergunta por vendedor, um a um —
  # aqui em uma query só, para filtrar/contar sem N+1). Usado pelo admin
  # (listagem e dashboard de artesãos).
  def self.accepted_current_terms_ids
    SellerTermsAcceptance.where(terms_version: SellerTerms.version).select(:seller_id)
  end

  # Composto em Seller.publicly_listed, onde a visibilidade pública é decidida
  # (Product.publicly_visible, Product#available_for_purchase?) — esconder
  # não muda o status do vendedor, é um filtro à parte.
  scope :visible, -> { where(hidden_at: nil) }

  # Fonte única de "o ateliê aparece na loja?": aprovado, ou liberado na
  # vitrine pelo admin durante o pré-cadastro, sempre fora do escondido.
  # Aparecer não é vender: a compra continua exigindo `approved?` (ver
  # Product#purchase_blocker). Suspenso nunca aparece, e `suspend!` também
  # limpa a vitrine.
  scope :publicly_listed, -> {
    visible.where(status: :approved).or(visible.where(status: :pending).where.not(showcased_at: nil))
  }

  # Nome livre para um novo ateliê? A unicidade é do slug, então "Ateliê da Ana"
  # e "atelie da ana" colidem. Devolve a sugestão mais próxima quando não é.
  def self.name_availability(name)
    base = name.to_s.strip.parameterize
    return { valid: false, available: false } if base.blank?

    taken = where("slug = :base OR slug LIKE :prefix", base: base, prefix: "#{sanitize_sql_like(base)}-%").pluck(:slug).to_set
    return { valid: true, available: true, slug: base } unless taken.include?(base)

    suffix = (2..).find { |n| taken.exclude?("#{base}-#{n}") }
    { valid: true, available: false, slug: base, suggestion: "#{name.to_s.strip} #{suffix}" }
  end

  before_validation :assign_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :mercado_pago_user_id, uniqueness: true, allow_blank: true
  validates :footer_text, length: { maximum: FOOTER_TEXT_MAX_LENGTH }
  validate :theme_images_allowed
  # Só exigido na criação: vendedores cadastrados antes deste campo existir
  # não têm o dado, e bloquear todo update (approve!, connect_mercado_pago!
  # etc.) até eles preencherem derrubaria o painel para quem já opera.
  # Preenchimento fica disponível em "Dados do Ateliê", mas não é obrigatório.
  validates :owner_full_name, presence: true, on: :create
  validates :cpf_hash, uniqueness: { message: "já está cadastrado para outro ateliê" }, allow_nil: true

  before_validation :assign_cpf, if: -> { @cpf.present? }
  validates :cpf, presence: true, on: :create
  validate :cpf_must_be_valid, if: -> { @cpf.present? }

  # O CEP é guardado só com dígitos: o vendedor digita com traço ou sem, e o
  # cálculo de frete compara com o CEP de destino, que já chega assim.
  normalizes :footer_text, with: ->(text) { text.to_s.strip.presence }
  normalizes :about_text, with: ->(text) { text.to_s.strip.presence }
  normalizes :notice_text, with: ->(text) { text.to_s.squish.presence }
  normalizes :theme_accent_color, with: ->(color) { color.to_s.strip.downcase.presence }
  # Aceita "@loja", "loja" ou a URL do perfil: guarda só o usuário.
  normalizes :instagram_handle, with: ->(handle) { handle.to_s.strip.sub(%r{\A(https?://)?(www\.)?instagram\.com/}i, "").delete_prefix("@").chomp("/").presence }
  normalizes :whatsapp_number, with: ->(number) { number.to_s.gsub(/\D/, "").presence }
  normalizes :theme_sections, with: ->(sections) { Array(sections).map(&:to_s).reject(&:blank?).uniq }
  normalizes :origin_zip_code, with: ->(zip) { zip.to_s.gsub(/\D/, "").presence }

  # Endereço opcional enquanto o frete real não está ligado: os vendedores já
  # cadastrados não o têm, e exigi-lo agora invalidaria o catálogo deles. Mas
  # quem preenche precisa preencher inteiro — meio endereço não despacha nada.
  validates :origin_zip_code, format: { with: /\A\d{8}\z/, message: "deve ter 8 dígitos" }, allow_blank: true
  validates :origin_street, :origin_number, :origin_neighborhood, :origin_city, :origin_state,
    presence: true, if: :origin_address_started?
  validates :origin_zip_code, presence: true, if: :origin_address_started?
  validates :origin_state, length: { is: 2 }, allow_blank: true

  LAUNCH_FEE_PERIOD = 3.months

  # A comissão de lançamento conta dos 3 primeiros meses em que o vendedor
  # pode vender: a aprovação dele ou a abertura das vendas da plataforma, o
  # que vier por último. Aprovado durante o pré-cadastro não perde o prazo
  # esperando a abertura. Sem um dos dois, o prazo ainda não começou.
  def launch_fee_starts_at
    sales_opened_at = PlatformSetting.sales_opened_at
    [ approved_at, sales_opened_at ].max if approved_at.present? && sales_opened_at.present?
  end

  def launch_fee_ends_at
    starts_at = launch_fee_starts_at
    starts_at + LAUNCH_FEE_PERIOD if starts_at.present?
  end

  def launch_fee_active?(at: Time.current)
    ends_at = launch_fee_ends_at
    ends_at.present? && at < ends_at
  end

  # Taxa que vale para uma venda feita agora. O checkout grava o resultado no
  # `SellerOrder`, então mudar de faixa não altera pedidos já criados.
  def platform_fee_rate_bps(at: Time.current)
    launch_fee_active?(at: at) ? SellerOrder::LAUNCH_PLATFORM_FEE_RATE_BPS : SellerOrder::PLATFORM_FEE_RATE_BPS
  end

  def approve!(kyc_level_6_confirmed: false)
    unless mercado_pago_connected? && approvable_account? && kyc_level_6_confirmed
      raise VerificationRequired, "Conecte uma conta Mercado Pago de produção e confirme o KYC nível 6 antes da aprovação."
    end

    now = Time.current
    update!(status: :approved, approved_at: now, showcased_at: showcased_at || now)
  end

  # Libera o ateliê pendente para aparecer na loja sem o Mercado Pago, depois
  # da revisão do admin. Aprovado já aparece (e esconder é `hide!`); suspenso
  # precisa ser reaprovado.
  def showcase!
    raise VerificationRequired, "Só um ateliê pendente pode ser liberado na vitrine." unless pending?

    update!(showcased_at: showcased_at || Time.current)
  end

  def unshowcase!
    raise VerificationRequired, "Só um ateliê pendente pode ser retirado da vitrine." unless pending?

    update!(showcased_at: nil)
  end

  def showcased?
    showcased_at.present?
  end

  def publicly_listed?
    return false if suspended? || hidden?

    approved? || showcased?
  end

  # Exigir conta real é a regra em produção, onde aprovar um vendedor de teste
  # deixaria dinheiro de cliente sem destino. Em sandbox a mesma exigência
  # torna o ambiente de teste inaprovável por construção — e, como publicar
  # produto exige aprovação (`Product.publicly_visible`), deixa o sandbox sem
  # catálogo e portanto sem como exercitar o checkout. Foi exatamente o que
  # travou o ateliê de teste em 2026-09-09, depois de uma reconexão zerar uma
  # aprovação que era anterior à salvaguarda.
  #
  # Falha fechado: sem `MERCADO_PAGO_MARKETPLACE_SANDBOX` ligada, o
  # comportamento é o de produção. Nenhum ambiente afrouxa por omissão.
  def approvable_account?
    mercado_pago_real_account? || Marketplace::MercadoPagoOauth.sandbox?
  end

  # Suspender também desconecta o Mercado Pago: caso contrário o token OAuth
  # continua válido e um pedido com pagamento pendente antes da suspensão
  # ainda conseguiria ser autorizado e repassar dinheiro ao vendedor suspenso
  # (nem `Payments::Authorize` nem o gateway checam `approved?`/`suspended?`,
  # só a presença do token). Pedidos já pagos antes da suspensão não são
  # mexidos aqui — reembolso, se necessário, é decisão manual do admin através
  # do fluxo de reembolso já existente.
  def suspend!
    update!(
      status: :suspended,
      approved_at: nil,
      showcased_at: nil,
      mercado_pago_user_id: nil,
      mercado_pago_access_token_ciphertext: nil,
      mercado_pago_refresh_token_ciphertext: nil,
      mercado_pago_token_expires_at: nil,
      mercado_pago_connected_at: nil,
      mercado_pago_live_mode: false,
      mercado_pago_test_account: nil,
      mercado_pago_public_key: nil
    )
  end

  # Diferente de suspend!, esconder não é moderação nem penalidade — é uma
  # pausa reversível que o admin decide (ex.: vendedor pediu para não
  # aparecer temporariamente). Por isso não mexe em status nem desconecta o
  # Mercado Pago: o vendedor continua approved e pode ser reexibido a
  # qualquer momento sem passar por reconexão ou novo KYC.
  def hide!
    update!(hidden_at: Time.current)
  end

  def unhide!
    update!(hidden_at: nil)
  end

  # A página pública /artesaos/:slug só existe para ateliê que aparece na loja
  # (ver SellersController#show): pendente fora da vitrine responde 404, e
  # suspenso ou escondido têm uma página de "indisponível". O "Ver a loja" do
  # painel usa isto para não mandar o vendedor a um beco.
  def public_page_available?
    publicly_listed?
  end

  def hidden?
    hidden_at.present?
  end

  # Basta um campo preenchido para o endereço passar a ser cobrado inteiro.
  def origin_address_started?
    ORIGIN_ADDRESS_FIELDS.any? { |field| public_send(field).present? }
  end

  # Pronto para despachar: o cálculo de frete real vai exigir isso.
  def origin_address_complete?
    ORIGIN_ADDRESS_FIELDS.all? { |field| public_send(field).present? }
  end

  # Conta real, apta a receber dinheiro de verdade. `live_mode` sozinho não
  # responde isso: o Mercado Pago o devolve `true` até para TESTUSER, e foi
  # por isso que um vendedor de teste chegou a ser aprovado. A tag
  # `test_user` de /users/me é o que distingue.
  #
  # `nil` (consulta falhou, ou conexão anterior a esta verificação) conta
  # como "não sei", e não passa: aprovar sem certeza é o risco que a
  # salvaguarda existe para evitar.
  def mercado_pago_real_account?
    mercado_pago_live_mode? && mercado_pago_test_account == false
  end

  # Etapas para começar a vender, na ordem da página "Primeiros passos". É a
  # fonte única: a página e o cartão do painel inicial leem daqui, para os dois
  # nunca discordarem sobre o que já está pronto. `pix_key` é declaração do
  # vendedor (o Mercado Pago não permite consultar se há chave PIX).
  def getting_started_steps
    {
      address: origin_address_complete?,
      mercado_pago: mercado_pago_connected?,
      pix_key: pix_key_confirmed_at.present?,
      product: products.exists?,
      approval: approved?
    }
  end

  # Pagos e ainda não despachados: o mesmo `:preparing` da linha do tempo do
  # pedido. É o "preparar e enviar" do painel inicial e da aba Pedidos.
  def seller_orders_to_prepare
    seller_orders.where(status: %w[confirmed partially_refunded]).joins(:shipment).merge(Shipment.pending)
  end

  # As mesmas etapas como o painel do artesão as cobra (bloco do painel
  # inicial e abas do celular): conta do Mercado Pago conectada mas não
  # aceita conta como pendente, porque é ela que o artesão precisa corrigir.
  def setup_steps
    steps = getting_started_steps
    steps[:mercado_pago] = false if mercado_pago_account_state == :not_accepted
    steps
  end

  def mercado_pago_connected?
    mercado_pago_user_id.present? &&
      mercado_pago_access_token_ciphertext.present? &&
      mercado_pago_refresh_token_ciphertext.present?
  end

  # `mercado_pago_connected?` só diz que há tokens: serve ao gateway e ao
  # OAuth, que precisam do token, mas não diz se a conta pode ser aprovada. O
  # painel usa este estado, que reaproveita `approvable_account?` (a mesma
  # regra de `approve!` e do botão do admin) para não mostrar "conectado" a
  # quem o admin não consegue aprovar — conta de teste em produção, ou
  # conexão anterior à verificação de origem (`test_account` nil).
  def mercado_pago_account_state
    return :not_connected unless mercado_pago_connected?

    approvable_account? ? :ready : :not_accepted
  end

  # Em que ponto da entrada o vendedor está, para o admin ver de relance quem
  # travou. Derivada do estado atual, sem coluna própria: não há como ficar
  # desatualizada em relação à conexão, à aprovação e aos pedidos.
  ONBOARDING_STAGES = %i[
    suspended awaiting_mercado_pago account_not_accepted awaiting_approval
    awaiting_first_product awaiting_first_sale selling
  ].freeze

  def onboarding_stage
    return :suspended if suspended?
    return :awaiting_mercado_pago unless mercado_pago_connected?
    return :account_not_accepted unless approvable_account?
    return :awaiting_approval unless approved?
    return :awaiting_first_product unless products.exists?
    return :awaiting_first_sale unless seller_orders.where.not(status: %w[pending cancelled]).exists?

    :selling
  end

  def connect_mercado_pago!(credentials)
    connection_attributes = {
      mercado_pago_user_id: credentials.user_id,
      mercado_pago_access_token_ciphertext: encrypt_credential(credentials.access_token, salt: CREDENTIAL_ENCRYPTION_SALT_MERCADO_PAGO),
      mercado_pago_refresh_token_ciphertext: encrypt_credential(credentials.refresh_token, salt: CREDENTIAL_ENCRYPTION_SALT_MERCADO_PAGO),
      mercado_pago_token_expires_at: credentials.expires_at,
      mercado_pago_connected_at: Time.current,
      mercado_pago_live_mode: credentials.live_mode,
      mercado_pago_test_account: credentials.test_account,
      mercado_pago_public_key: credentials.public_key
    }
    if mercado_pago_user_id != credentials.user_id
      connection_attributes.merge!(status: :pending, approved_at: nil)
    end

    update!(connection_attributes)
  end

  # Volta para `pending`, mas não mexe em `showcased_at`: o ateliê continua
  # na loja e só para de vender até reconectar e ser reaprovado.
  def disconnect_mercado_pago!
    update!(
      mercado_pago_user_id: nil,
      mercado_pago_access_token_ciphertext: nil,
      mercado_pago_refresh_token_ciphertext: nil,
      mercado_pago_token_expires_at: nil,
      mercado_pago_connected_at: nil,
      mercado_pago_live_mode: false,
      mercado_pago_test_account: nil,
      mercado_pago_public_key: nil,
      status: :pending,
      approved_at: nil
    )
  end

  # Cartão de crédito (Fase 24) exige a Public Key do vendedor no front; sem
  # ela — vendedor conectado antes desta fase, por exemplo — a UI de cartão
  # não é oferecida, mas PIX continua funcionando normalmente.
  def mercado_pago_card_payments_available?
    mercado_pago_connected? && mercado_pago_public_key.present?
  end

  def mercado_pago_access_token
    decrypt_credential(mercado_pago_access_token_ciphertext, salt: CREDENTIAL_ENCRYPTION_SALT_MERCADO_PAGO)
  end

  def mercado_pago_refresh_token
    decrypt_credential(mercado_pago_refresh_token_ciphertext, salt: CREDENTIAL_ENCRYPTION_SALT_MERCADO_PAGO)
  end

  # Frete real via Melhor Envio (ADR 005, Etapa 1). Mesmo padrão do Mercado
  # Pago: cada vendedor conecta a própria conta via OAuth, tokens cifrados.
  # Sem user_id: a API do Melhor Envio não devolve identificador de conta no
  # token exchange (ver Marketplace::MelhorEnvioOauth).
  def melhor_envio_connected?
    melhor_envio_access_token_ciphertext.present? && melhor_envio_refresh_token_ciphertext.present?
  end

  def connect_melhor_envio!(credentials, sandbox: false)
    update!(
      melhor_envio_access_token_ciphertext: encrypt_credential(credentials.access_token, salt: CREDENTIAL_ENCRYPTION_SALT_MELHOR_ENVIO),
      melhor_envio_refresh_token_ciphertext: encrypt_credential(credentials.refresh_token, salt: CREDENTIAL_ENCRYPTION_SALT_MELHOR_ENVIO),
      melhor_envio_token_expires_at: credentials.expires_at,
      melhor_envio_connected_at: Time.current,
      melhor_envio_sandbox: sandbox
    )
  end

  def disconnect_melhor_envio!
    update!(
      melhor_envio_access_token_ciphertext: nil,
      melhor_envio_refresh_token_ciphertext: nil,
      melhor_envio_token_expires_at: nil,
      melhor_envio_connected_at: nil,
      melhor_envio_sandbox: false
    )
  end

  def melhor_envio_access_token
    decrypt_credential(melhor_envio_access_token_ciphertext, salt: CREDENTIAL_ENCRYPTION_SALT_MELHOR_ENVIO)
  end

  def melhor_envio_refresh_token
    decrypt_credential(melhor_envio_refresh_token_ciphertext, salt: CREDENTIAL_ENCRYPTION_SALT_MELHOR_ENVIO)
  end

  # CPF nunca é lido de volta em texto plano fora do cadastro (write-only na
  # prática): o dígito é guardado cifrado, e a checagem de duplicidade usa um
  # hash determinístico à parte, já que o ciphertext (IV aleatório) muda a
  # cada gravação e não serve para comparação de unicidade.
  attr_reader :cpf

  def cpf=(value)
    @cpf = value.to_s.gsub(/\D/, "")
  end

  # Exibição apenas: "***.***.***-35". O CPF completo nunca volta para a
  # tela — só os dois últimos dígitos, suficientes para o vendedor reconhecer
  # o próprio cadastro sem reexpor o documento inteiro.
  def masked_cpf
    digits = decrypted_cpf
    return nil if digits.blank?

    "***.***.***-#{digits.last(2)}"
  end

  # CPF completo formatado, só para telas administrativas (o admin da
  # plataforma precisa do documento íntegro para fins de aprovação/KYC).
  # Em qualquer outro lugar — inclusive o próprio painel do vendedor — use
  # `masked_cpf`.
  def cpf_for_admin
    digits = decrypted_cpf
    return nil if digits.blank?

    "#{digits[0..2]}.#{digits[3..5]}.#{digits[6..8]}-#{digits[9..10]}"
  end

  def to_param
    slug
  end

  def terms_accepted?
    SellerTermsAcceptance.exists?(seller: self, terms_version: SellerTerms.version)
  end

  def latest_terms_acceptance
    seller_terms_acceptances.order(accepted_at: :desc).first
  end

  # As peças da vitrine pública (e da pré-visualização do tema), já com o que
  # os cards usam carregado. preload, e não includes: a capa arrasta as
  # tabelas do Active Storage e o plano estourava o jit_above_cost no
  # catálogo (ver Fase 17). `personalization_options` entra porque o card
  # pergunta se a peça aceita compra rápida e isso era 1 query por card.
  def storefront_products
    products.publicly_visible
      .order(created_at: :desc)
      .preload(:seller, :product_variants, :personalization_options, category: :parent)
      .preload_main_image
      .load
  end

  private

  CREDENTIAL_ENCRYPTION_SALT_MERCADO_PAGO = "seller-mercado-pago-oauth".freeze
  CREDENTIAL_ENCRYPTION_SALT_MELHOR_ENVIO = "seller-melhor-envio-oauth".freeze
  CREDENTIAL_ENCRYPTION_SALT_CPF = "seller-owner-cpf".freeze

  def assign_cpf
    self.cpf_ciphertext = encrypt_credential(cpf, salt: CREDENTIAL_ENCRYPTION_SALT_CPF)
    self.cpf_hash = Digest::SHA256.hexdigest(cpf)
  end

  # Módulo 11: valida os dois dígitos verificadores contra os 9 primeiros
  # dígitos do CPF. Rejeita também sequências de dígito repetido (111...,
  # 222...), que passam no módulo 11 mas não são CPF válido.
  def cpf_must_be_valid
    return errors.add(:cpf, "deve ter 11 dígitos") unless cpf.match?(/\A\d{11}\z/)
    return errors.add(:cpf, "é inválido") if cpf.chars.uniq.one?
    errors.add(:cpf, "é inválido") unless valid_cpf_checksum?(cpf)
  end

  def valid_cpf_checksum?(digits)
    [ 9, 10 ].all? do |length|
      base = digits[0...length]
      weights = (length + 1).downto(2)
      sum = base.chars.map(&:to_i).zip(weights).sum { |digit, weight| digit * weight }
      remainder = (sum * 10) % 11
      remainder = 0 if remainder == 10
      remainder == digits[length].to_i
    end
  end

  def decrypted_cpf
    decrypt_credential(cpf_ciphertext, salt: CREDENTIAL_ENCRYPTION_SALT_CPF)
  end

  def credential_encryptor(salt:)
    key = Rails.application.key_generator.generate_key(salt, ActiveSupport::MessageEncryptor.key_len)
    ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
  end

  def encrypt_credential(value, salt:)
    credential_encryptor(salt: salt).encrypt_and_sign(value)
  end

  def decrypt_credential(ciphertext, salt:)
    credential_encryptor(salt: salt).decrypt_and_verify(ciphertext) if ciphertext.present?
  end

  def assign_slug
    self.slug = name.parameterize
  end

  # Sem o catálogo a vitrine não tem sentido; mantê-lo aqui evita que um
  # formulário adulterado (ou lista vazia) esconda as peças.
  def ensure_catalog_section
    self.theme_sections = theme_sections + [ "catalog" ] unless theme_sections.include?("catalog")
  end

  def theme_sections_known
    unknown = theme_sections - SellerTheme::SECTIONS.keys
    errors.add(:theme_sections, "tem seção desconhecida") if unknown.any?
  end

  def theme_accent_color_readable
    return if theme_accent_color.blank?

    if !theme_accent_color.match?(SellerTheme::HEX_COLOR)
      errors.add(:theme_accent_color, "deve ser uma cor no formato #rrggbb")
    elsif SellerTheme.contrast_ratio(theme_accent_color) < SellerTheme::MIN_ACCENT_CONTRAST
      errors.add(:theme_accent_color, "é clara demais: o texto sobre ela ficaria difícil de ler. Escolha uma cor mais escura")
    end
  end

  def theme_images_allowed
    %i[logo cover_image about_image].each do |name|
      image = public_send(name)
      next unless image.attached?

      errors.add(name, "deve ser um arquivo PNG, JPEG ou WEBP") unless THEME_IMAGE_CONTENT_TYPES.include?(image.content_type)
      errors.add(name, "deve ter no máximo 5MB") if image.byte_size > THEME_IMAGE_MAX_BYTES
    end
  end
end
