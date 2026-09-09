class Seller < ApplicationRecord
  class VerificationRequired < StandardError; end

  enum :status, {
    pending: "pending",
    approved: "approved",
    suspended: "suspended"
  }, default: "pending"

  ORIGIN_ADDRESS_FIELDS = %i[
    origin_zip_code origin_street origin_number origin_neighborhood origin_city origin_state
  ].freeze

  has_many :users, dependent: :restrict_with_error
  has_many :products, dependent: :restrict_with_error
  has_many :seller_orders, dependent: :restrict_with_error

  before_validation :assign_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :mercado_pago_user_id, uniqueness: true, allow_blank: true

  # O CEP é guardado só com dígitos: o vendedor digita com traço ou sem, e o
  # cálculo de frete compara com o CEP de destino, que já chega assim.
  normalizes :origin_zip_code, with: ->(zip) { zip.to_s.gsub(/\D/, "").presence }

  # Endereço opcional enquanto o frete real não está ligado: os vendedores já
  # cadastrados não o têm, e exigi-lo agora invalidaria o catálogo deles. Mas
  # quem preenche precisa preencher inteiro — meio endereço não despacha nada.
  validates :origin_zip_code, format: { with: /\A\d{8}\z/, message: "deve ter 8 dígitos" }, allow_blank: true
  validates :origin_street, :origin_number, :origin_neighborhood, :origin_city, :origin_state,
    presence: true, if: :origin_address_started?
  validates :origin_zip_code, presence: true, if: :origin_address_started?
  validates :origin_state, length: { is: 2 }, allow_blank: true

  def approve!(kyc_level_6_confirmed: false)
    unless mercado_pago_connected? && approvable_account? && kyc_level_6_confirmed
      raise VerificationRequired, "Conecte uma conta Mercado Pago de produção e confirme o KYC nível 6 antes da aprovação."
    end

    update!(status: :approved, approved_at: Time.current)
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

  def suspend!
    update!(status: :suspended, approved_at: nil)
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

  def mercado_pago_connected?
    mercado_pago_user_id.present? &&
      mercado_pago_access_token_ciphertext.present? &&
      mercado_pago_refresh_token_ciphertext.present?
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

  def to_param
    slug
  end

  private

  CREDENTIAL_ENCRYPTION_SALT_MERCADO_PAGO = "seller-mercado-pago-oauth".freeze
  CREDENTIAL_ENCRYPTION_SALT_MELHOR_ENVIO = "seller-melhor-envio-oauth".freeze

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
end
