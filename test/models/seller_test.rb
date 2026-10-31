require "test_helper"

class SellerTest < ActiveSupport::TestCase
  test "assigns a slug and starts pending" do
    seller = Seller.create!(name: "Ateliê da Lua", owner_full_name: "Ana Lua", cpf: "11144477735")

    assert_equal "atelie-da-lua", seller.slug
    assert_predicate seller, :pending?
    assert_nil seller.approved_at
  end

  test "name_availability detects slug collisions and suggests a free name" do
    Seller.create!(name: "Ateliê da Lua", owner_full_name: "Ana Lua", cpf: "11144477735")

    assert_equal({ valid: true, available: true, slug: "atelie-do-sol" }, Seller.name_availability("Ateliê do Sol"))

    taken = Seller.name_availability("  atelie DA lua ")
    assert_equal false, taken[:available]
    assert_equal "atelie DA lua 2", taken[:suggestion]

    Seller.create!(name: "Ateliê da Lua 2", owner_full_name: "Bia Lua", cpf: "52998224725")
    assert_equal "Ateliê da Lua 3", Seller.name_availability("Ateliê da Lua")[:suggestion]

    assert_equal({ valid: false, available: false }, Seller.name_availability("!!!"))
  end

  test "accepted_current_terms_ids matches terms_accepted? for every seller" do
    accepted_seller = sellers(:approved)
    accepted_user = User.create!(email_address: "terms-ok-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: accepted_seller)
    SellerTermsAcceptance.create!(
      user: accepted_user, seller: accepted_seller, terms_version: SellerTerms.version, terms_text: SellerTerms.text,
      terms_digest: Digest::SHA256.hexdigest(SellerTerms.text), accepted_at: Time.current, ip_address: "127.0.0.1"
    )
    pending_seller = sellers(:pending)

    ids = Seller.accepted_current_terms_ids.map(&:seller_id)

    assert_includes ids, accepted_seller.id
    assert_not_includes ids, pending_seller.id
    assert accepted_seller.terms_accepted?
    assert_not pending_seller.terms_accepted?
  end

  test "launch fee is 8% until 3 months after approval and 15% afterwards" do
    seller = sellers(:approved)
    seller.update!(approved_at: Time.zone.local(2026, 10, 3, 12))

    assert_equal Time.zone.local(2027, 1, 3, 12), seller.launch_fee_ends_at
    assert_equal 800, seller.platform_fee_rate_bps(at: Time.zone.local(2026, 10, 3, 12))
    assert_equal 800, seller.platform_fee_rate_bps(at: Time.zone.local(2027, 1, 3, 11, 59))
    assert_predicate seller, :launch_fee_active?
    assert_equal 1_500, seller.platform_fee_rate_bps(at: Time.zone.local(2027, 1, 3, 12))
    assert_not seller.launch_fee_active?(at: Time.zone.local(2027, 6, 1))
  end

  test "a seller approved during pre-registration starts the launch fee when sales open" do
    PlatformSetting.instance.update!(sales_opened_at: nil)
    seller = sellers(:approved)
    seller.update!(approved_at: Time.zone.local(2026, 10, 28, 12))

    assert_nil seller.launch_fee_ends_at
    assert_not seller.launch_fee_active?
    assert_equal 1_500, seller.platform_fee_rate_bps

    PlatformSetting.instance.update!(sales_opened_at: Time.zone.local(2026, 11, 15, 9))

    assert_equal Time.zone.local(2026, 11, 15, 9), seller.launch_fee_starts_at
    assert_equal Time.zone.local(2027, 2, 15, 9), seller.launch_fee_ends_at
    assert_equal 800, seller.platform_fee_rate_bps(at: Time.zone.local(2027, 2, 15, 8, 59))
  end

  test "a seller approved after sales opened starts the launch fee on approval" do
    PlatformSetting.instance.update!(sales_opened_at: Time.zone.local(2026, 11, 15, 9))
    seller = sellers(:approved)
    seller.update!(approved_at: Time.zone.local(2026, 12, 1, 10))

    assert_equal Time.zone.local(2026, 12, 1, 10), seller.launch_fee_starts_at
  end

  test "a seller that was never approved has no launch period running" do
    seller = sellers(:pending)

    assert_nil seller.approved_at
    assert_nil seller.launch_fee_ends_at
    assert_not seller.launch_fee_active?
    assert_equal 1_500, seller.platform_fee_rate_bps
  end

  test "approval and suspension preserve explicit status" do
    seller = sellers(:pending)
    seller.connect_mercado_pago!(mercado_pago_credentials)

    seller.approve!(kyc_level_6_confirmed: true)
    assert_predicate seller, :approved?
    assert_not_nil seller.approved_at

    seller.suspend!
    assert_predicate seller, :suspended?
    assert_nil seller.approved_at
  end

  # Sem isto, o token OAuth continuaria válido após a suspensão, e um pedido
  # com pagamento pendente criado antes dela ainda conseguiria ser autorizado
  # — nem `Payments::Authorize` nem o gateway checam `approved?`/`suspended?`,
  # só a presença do token (ver Seller#suspend!).
  test "suspension disconnects Mercado Pago instead of just changing status" do
    seller = sellers(:pending)
    seller.connect_mercado_pago!(mercado_pago_credentials)
    seller.approve!(kyc_level_6_confirmed: true)
    assert_predicate seller, :mercado_pago_connected?

    seller.suspend!

    assert_predicate seller, :suspended?
    assert_not_predicate seller, :mercado_pago_connected?
    assert_nil seller.mercado_pago_user_id
    assert_nil seller.mercado_pago_access_token_ciphertext
    assert_nil seller.mercado_pago_refresh_token_ciphertext
    assert_nil seller.mercado_pago_public_key
  end

  # Diferente de suspend!, esconder não é moderação: o vendedor continua
  # approved e conectado ao Mercado Pago, só não aparece publicamente.
  test "hiding does not change status nor disconnect Mercado Pago" do
    seller = sellers(:pending)
    seller.connect_mercado_pago!(mercado_pago_credentials)
    seller.approve!(kyc_level_6_confirmed: true)

    seller.hide!

    assert_predicate seller, :hidden?
    assert_predicate seller, :approved?
    assert_predicate seller, :mercado_pago_connected?
  end

  test "unhiding reverses hide! without touching approval" do
    seller = sellers(:pending)
    seller.connect_mercado_pago!(mercado_pago_credentials)
    seller.approve!(kyc_level_6_confirmed: true)
    seller.hide!

    seller.unhide!

    assert_not_predicate seller, :hidden?
    assert_predicate seller, :approved?
  end

  test "approval requires a connected account and explicit KYC confirmation" do
    seller = sellers(:pending)

    assert_raises(Seller::VerificationRequired) { seller.approve!(kyc_level_6_confirmed: true) }

    seller.connect_mercado_pago!(mercado_pago_credentials)
    assert_raises(Seller::VerificationRequired) { seller.approve! }
    assert_predicate seller, :pending?
  end

  test "approval rejects a Mercado Pago test account" do
    seller = sellers(:pending)
    seller.connect_mercado_pago!(mercado_pago_credentials(live_mode: false))

    # Fora do sandbox, explicitamente: a recusa não pode depender de a
    # variável de ambiente estar setada na máquina de quem roda a suíte.
    with_sandbox(nil) do
      assert_raises(Seller::VerificationRequired) do
        seller.approve!(kyc_level_6_confirmed: true)
      end
    end
    assert_predicate seller, :pending?
  end

  test "stores Mercado Pago tokens encrypted and disconnecting returns to pending" do
    seller = sellers(:pending)
    seller.connect_mercado_pago!(mercado_pago_credentials)

    assert_predicate seller, :mercado_pago_connected?
    assert_equal "seller-access-token", seller.mercado_pago_access_token
    assert_equal "seller-refresh-token", seller.mercado_pago_refresh_token
    assert_not_includes seller.mercado_pago_access_token_ciphertext, "seller-access-token"

    seller.approve!(kyc_level_6_confirmed: true)
    seller.disconnect_mercado_pago!

    assert_predicate seller, :pending?
    assert_not_predicate seller, :mercado_pago_connected?
    assert_nil seller.approved_at
  end

  # Contraparte do teste seguinte, e a invariante em que o botão "Reconectar"
  # do painel se apoia: reautorizar a MESMA conta atualiza as credenciais sem
  # tocar em `status`/`approved_at`. É o caminho de quem conectou antes da
  # Fase 24 e precisa gravar a Public Key para o cartão aparecer — sem
  # despublicar o catálogo, o que "Desconectar" faria.
  test "reconnecting the same Mercado Pago account keeps the approval and stores the public key" do
    seller = sellers(:pending)
    seller.connect_mercado_pago!(mercado_pago_credentials(public_key: nil))
    seller.approve!(kyc_level_6_confirmed: true)

    assert_predicate seller, :approved?
    assert_nil seller.mercado_pago_public_key
    assert_not_predicate seller, :mercado_pago_card_payments_available?

    approved_at = seller.approved_at
    seller.connect_mercado_pago!(mercado_pago_credentials(public_key: "TEST-public-key-nova"))

    assert_predicate seller, :approved?
    assert_equal approved_at, seller.approved_at
    assert_equal "TEST-public-key-nova", seller.mercado_pago_public_key
    assert_predicate seller, :mercado_pago_card_payments_available?
  end

  test "changing the connected Mercado Pago account requires a new approval" do
    seller = sellers(:approved)

    seller.connect_mercado_pago!(mercado_pago_credentials)

    assert_predicate seller, :pending?
    assert_nil seller.approved_at
  end

  test "stores Melhor Envio tokens encrypted and disconnecting clears the connection" do
    seller = sellers(:pending)
    credentials = Marketplace::MelhorEnvioOauth::Credentials.new(
      access_token: "melhor-envio-access-token",
      refresh_token: "melhor-envio-refresh-token",
      expires_at: 30.days.from_now
    )

    seller.connect_melhor_envio!(credentials, sandbox: true)

    assert_predicate seller, :melhor_envio_connected?
    assert seller.melhor_envio_sandbox?
    assert_equal "melhor-envio-access-token", seller.melhor_envio_access_token
    assert_equal "melhor-envio-refresh-token", seller.melhor_envio_refresh_token
    assert_not_includes seller.melhor_envio_access_token_ciphertext, "melhor-envio-access-token"

    seller.disconnect_melhor_envio!

    assert_not_predicate seller, :melhor_envio_connected?
    assert_nil seller.melhor_envio_access_token
  end

  test "requires the owner's full name and CPF" do
    seller = Seller.new(name: "Sem dono")

    assert_not seller.valid?
    assert_includes seller.errors[:owner_full_name], "não pode ficar em branco"
    assert_includes seller.errors[:cpf], "não pode ficar em branco"
  end

  test "formats a CPF progressively and keeps more than 11 digits unmasked" do
    assert_equal "123.456.789-09", Seller.format_cpf("12345678909")
    assert_equal "123.456.789-09", Seller.format_cpf("123.456.789-09")
    assert_equal "123.4", Seller.format_cpf("1234")
    assert_equal "123", Seller.format_cpf("123")
    assert_equal "123.456.789-0", Seller.format_cpf("1234567890")
    assert_equal "", Seller.format_cpf(nil)
    assert_equal "123456789012", Seller.format_cpf("123456789012")
  end

  test "a blank name reports only the name, not the URL derived from it" do
    seller = Seller.new(name: "", owner_full_name: "Fulana", cpf: "52998224725")

    assert_not seller.valid?
    assert_predicate seller.errors[:name], :any?
    assert_empty seller.errors[:slug]
  end

  test "rejects a CPF with an invalid checksum" do
    seller = Seller.new(name: "Ateliê", owner_full_name: "Ana Lua", cpf: "11144477736")

    assert_not seller.valid?
    assert_includes seller.errors[:cpf], "é inválido"
  end

  test "rejects a CPF with all repeated digits" do
    seller = Seller.new(name: "Ateliê", owner_full_name: "Ana Lua", cpf: "11111111111")

    assert_not seller.valid?
    assert_includes seller.errors[:cpf], "é inválido"
  end

  test "accepts a CPF formatted with punctuation" do
    seller = Seller.new(name: "Ateliê", owner_full_name: "Ana Lua", cpf: "111.444.777-35")

    assert seller.valid?
    assert_equal "11144477735", seller.cpf
  end

  test "stores the CPF encrypted and rejects a duplicate across sellers" do
    first = Seller.create!(name: "Primeiro Ateliê", owner_full_name: "Ana Lua", cpf: "111.444.777-35")

    assert_not_includes first.cpf_ciphertext, "11144477735"

    duplicate = Seller.new(name: "Segundo Ateliê", owner_full_name: "Outro Dono", cpf: "111.444.777-35")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:cpf_hash], "já está cadastrado para outro ateliê"
  end

  test "masks the CPF for display, showing only the last two digits" do
    seller = Seller.create!(name: "Ateliê", owner_full_name: "Ana Lua", cpf: "111.444.777-35")

    assert_equal "***.***.***-35", seller.masked_cpf
  end

  test "masked CPF is nil when none was ever stored" do
    seller = Seller.create!(name: "Ateliê", owner_full_name: "Ana Lua", cpf: "39053344705")
    seller.update_columns(cpf_ciphertext: nil, cpf_hash: nil)

    assert_nil seller.masked_cpf
  end

  # Formatação completa, reservada para telas administrativas — em qualquer
  # outro lugar (incluindo o próprio painel do vendedor) o dado exibido deve
  # ser `masked_cpf`.
  test "returns the complete formatted CPF for admin screens" do
    seller = Seller.create!(name: "Ateliê", owner_full_name: "Ana Lua", cpf: "111.444.777-35")

    assert_equal "111.444.777-35", seller.cpf_for_admin
  end

  test "complete CPF for admin is nil when none was ever stored" do
    seller = Seller.create!(name: "Ateliê", owner_full_name: "Ana Lua", cpf: "39053344705")
    seller.update_columns(cpf_ciphertext: nil, cpf_hash: nil)

    assert_nil seller.cpf_for_admin
  end

  # owner_full_name/cpf só são exigidos na criação: vendedores cadastrados
  # antes deste campo existir não têm o dado, e operações centrais do painel
  # (aprovação, conexão de gateway) não podem ficar bloqueadas até eles
  # preencherem — ver comentário em Seller#owner_full_name.
  test "core seller operations keep working for a legacy seller without owner data" do
    legacy_seller = Seller.create!(name: "Ateliê Legado", owner_full_name: "Temporário", cpf: "16899535009")
    legacy_seller.update_columns(owner_full_name: nil, cpf_ciphertext: nil, cpf_hash: nil)

    legacy_seller.connect_mercado_pago!(mercado_pago_credentials)
    legacy_seller.approve!(kyc_level_6_confirmed: true)

    assert_predicate legacy_seller.reload, :approved?
  end

  test "Mercado Pago and Melhor Envio credentials are encrypted independently" do
    seller = sellers(:pending)
    seller.connect_mercado_pago!(mercado_pago_credentials)
    seller.connect_melhor_envio!(
      Marketplace::MelhorEnvioOauth::Credentials.new(
        access_token: "melhor-envio-access-token", refresh_token: "melhor-envio-refresh-token", expires_at: 30.days.from_now
      )
    )

    assert_not_equal seller.mercado_pago_access_token_ciphertext, seller.melhor_envio_access_token_ciphertext
    assert_equal "seller-access-token", seller.mercado_pago_access_token
    assert_equal "melhor-envio-access-token", seller.melhor_envio_access_token
  end

  test "a pending seller is not publicly listed until the admin showcases it" do
    seller = sellers(:pending)

    assert_not_predicate seller, :publicly_listed?
    assert_not_includes Seller.publicly_listed, seller

    seller.showcase!

    assert_predicate seller, :showcased?
    assert_predicate seller, :pending?
    assert_predicate seller, :publicly_listed?
    assert_includes Seller.publicly_listed, seller
    assert_not_predicate seller, :mercado_pago_connected?
  end

  test "unshowcasing takes a pending seller back out of the store" do
    seller = sellers(:pending)
    seller.showcase!

    seller.unshowcase!

    assert_not_predicate seller, :showcased?
    assert_not_includes Seller.publicly_listed, seller
  end

  test "only a pending seller can be showcased or unshowcased" do
    approved = sellers(:approved)
    suspended = sellers(:other).tap(&:suspend!)

    assert_raises(Seller::VerificationRequired) { approved.showcase! }
    assert_raises(Seller::VerificationRequired) { approved.unshowcase! }
    assert_raises(Seller::VerificationRequired) { suspended.showcase! }
  end

  test "a hidden or suspended seller is never publicly listed, even when showcased" do
    seller = sellers(:pending)
    seller.showcase!

    seller.hide!
    assert_not_predicate seller, :publicly_listed?
    assert_not_includes Seller.publicly_listed, seller

    seller.unhide!
    seller.suspend!
    assert_nil seller.showcased_at
    assert_not_predicate seller, :publicly_listed?
  end

  test "approval keeps the seller listed after disconnecting Mercado Pago, without selling" do
    seller = sellers(:pending)
    seller.connect_mercado_pago!(mercado_pago_credentials)
    seller.approve!(kyc_level_6_confirmed: true)
    assert_not_nil seller.showcased_at

    seller.disconnect_mercado_pago!

    assert_predicate seller, :pending?
    assert_predicate seller, :publicly_listed?
  end

  test "approval preserves the showcase date of a seller already in the store" do
    seller = sellers(:pending)
    seller.showcase!
    showcased_at = seller.showcased_at

    seller.connect_mercado_pago!(mercado_pago_credentials)
    seller.approve!(kyc_level_6_confirmed: true)

    assert_equal showcased_at, seller.showcased_at
  end

  test "showcasing does not start the launch fee period" do
    seller = sellers(:pending)
    seller.showcase!

    assert_nil seller.launch_fee_starts_at
  end

  private

  # O modo sandbox vem de variável de ambiente (lida por
  # Marketplace::MercadoPagoOauth), então o teste a define e restaura em vez
  # de stubar — mesma convenção de test/services/gateways/mercado_pago_test.rb.
  def with_sandbox(value)
    original = ENV["MERCADO_PAGO_MARKETPLACE_SANDBOX"]
    value.nil? ? ENV.delete("MERCADO_PAGO_MARKETPLACE_SANDBOX") : ENV["MERCADO_PAGO_MARKETPLACE_SANDBOX"] = value
    yield
  ensure
    original.nil? ? ENV.delete("MERCADO_PAGO_MARKETPLACE_SANDBOX") : ENV["MERCADO_PAGO_MARKETPLACE_SANDBOX"] = original
  end

  # `test_account: false` é o padrão porque a maioria dos casos descreve uma
  # conta real; os testes de conta de teste passam `true` explicitamente.
  test "onboarding stage follows the seller from signup to the first sale" do
    seller = sellers(:pending)
    assert_equal :awaiting_mercado_pago, seller.onboarding_stage

    seller.connect_mercado_pago!(mercado_pago_credentials(live_mode: false, test_account: true))
    assert_equal :account_not_accepted, seller.onboarding_stage

    seller.connect_mercado_pago!(mercado_pago_credentials)
    assert_equal :awaiting_approval, seller.onboarding_stage

    seller.approve!(kyc_level_6_confirmed: true)
    assert_equal :awaiting_first_product, seller.onboarding_stage

    seller.suspend!
    assert_equal :suspended, seller.onboarding_stage
  end

  test "onboarding stage waits for the first confirmed sale and then reports selling" do
    seller = sellers(:approved)
    seller.connect_mercado_pago!(mercado_pago_credentials)
    seller.update!(status: :approved, approved_at: Time.current)

    assert_equal :awaiting_first_sale, seller.onboarding_stage

    seller.seller_orders.first.update!(status: :confirmed)
    assert_equal :selling, seller.onboarding_stage
  end

  def mercado_pago_credentials(live_mode: true, test_account: false, public_key: "TEST-public-key")
    Marketplace::MercadoPagoOauth::Credentials.new(
      user_id: "123456",
      access_token: "seller-access-token",
      refresh_token: "seller-refresh-token",
      expires_at: 180.days.from_now,
      live_mode: live_mode,
      test_account: test_account,
      public_key: public_key
    )
  end

  # Endereço de origem: opcional enquanto o frete real não está ligado, mas
  # quem começa a preencher precisa terminar — meio endereço não despacha.
  test "is valid without an origin address" do
    assert Seller.new(name: "Sem endereço", owner_full_name: "Ana Lua", cpf: "24681357928").valid?
  end

  test "requires the whole origin address once one field is filled" do
    seller = Seller.new(name: "Parcial", origin_city: "Florianópolis")

    assert_not seller.valid?
    assert seller.origin_address_started?
    assert_not seller.origin_address_complete?
  end

  test "accepts a complete origin address" do
    seller = Seller.new(name: "Completo", owner_full_name: "Ana Lua", cpf: "19283746546",
      origin_zip_code: "88010-000", origin_street: "Rua A",
      origin_number: "10", origin_neighborhood: "Centro", origin_city: "Florianópolis", origin_state: "SC")

    assert seller.valid?
    assert seller.origin_address_complete?
  end

  # O CEP é comparado com o de destino, que chega só com dígitos.
  test "normalizes the origin zip code to digits" do
    seller = Seller.new(name: "CEP", origin_zip_code: "88010-000")

    assert_equal "88010000", seller.origin_zip_code
  end

  test "rejects an origin zip code that is not eight digits" do
    seller = Seller.new(name: "CEP curto", origin_zip_code: "8801")

    assert_not seller.valid?
    assert_includes seller.errors[:origin_zip_code], "deve ter 8 dígitos"
  end

  # `live_mode` vem `true` também para TESTUSER — foi assim que uma conta de
  # teste chegou a ser aprovada em produção. Quem distingue é a tag
  # `test_user` de /users/me.
  test "refuses approval for a Mercado Pago test account" do
    seller = Seller.create!(name: "Ateliê de teste", owner_full_name: "Ana Lua", cpf: "52998224725")
    seller.connect_mercado_pago!(mercado_pago_credentials(live_mode: true, test_account: true))

    assert seller.mercado_pago_connected?
    assert seller.mercado_pago_live_mode?
    assert_not seller.mercado_pago_real_account?
    # Explícito de propósito: sem isto o resultado dependeria de a variável
    # de sandbox estar ou não no ambiente de quem roda a suíte.
    with_sandbox(nil) do
      assert_raises(Seller::VerificationRequired) { seller.approve!(kyc_level_6_confirmed: true) }
    end
  end

  # Sem certeza sobre a conta, a aprovação não passa: aprovar no escuro é o
  # risco que a salvaguarda existe para evitar.
  test "refuses approval when the account type is unknown" do
    seller = Seller.create!(name: "Ateliê indefinido", owner_full_name: "Ana Lua", cpf: "39053344705")
    seller.connect_mercado_pago!(mercado_pago_credentials(live_mode: true, test_account: nil))

    assert_nil seller.mercado_pago_test_account
    assert_not seller.mercado_pago_real_account?
    with_sandbox(nil) do
      assert_raises(Seller::VerificationRequired) { seller.approve!(kyc_level_6_confirmed: true) }
    end
  end

  # O painel não pode dizer "conectado" a quem o admin não consegue aprovar:
  # `mercado_pago_connected?` só sabe que há tokens. O estado usa a mesma
  # regra da aprovação (`approvable_account?`), então os dois não divergem.
  test "account state separates missing, not accepted and ready connections" do
    seller = Seller.create!(name: "Ateliê estados", owner_full_name: "Ana Lua", cpf: "52998224725")

    with_sandbox(nil) do
      assert_equal :not_connected, seller.mercado_pago_account_state

      seller.connect_mercado_pago!(mercado_pago_credentials(live_mode: true, test_account: true))
      assert seller.mercado_pago_connected?
      assert_equal :not_accepted, seller.mercado_pago_account_state

      seller.update!(mercado_pago_test_account: nil)
      assert_equal :not_accepted, seller.mercado_pago_account_state

      seller.update!(mercado_pago_test_account: false)
      assert_equal :ready, seller.mercado_pago_account_state
    end
  end

  test "account state accepts a test account while the app runs in sandbox mode" do
    seller = Seller.create!(name: "Ateliê estados sandbox", owner_full_name: "Ana Lua", cpf: "39053344705")
    seller.connect_mercado_pago!(mercado_pago_credentials(live_mode: false, test_account: true))

    with_sandbox("true") { assert_equal :ready, seller.mercado_pago_account_state }
  end

  # Contrapartida das duas recusas acima: em sandbox o ambiente inteiro é de
  # teste, e exigir conta real ali deixa o ateliê de teste inaprovável — logo
  # sem catálogo publicado (`Product.publicly_visible` exige `approved`) e sem
  # checkout para exercitar. As recusas continuam valendo fora do sandbox, que
  # é onde a salvaguarda protege dinheiro real.
  test "approves a Mercado Pago test account while the app runs in sandbox mode" do
    seller = Seller.create!(name: "Ateliê de teste em sandbox", owner_full_name: "Ana Lua", cpf: "16899535009")
    seller.connect_mercado_pago!(mercado_pago_credentials(live_mode: false, test_account: true))

    assert_not seller.mercado_pago_real_account?

    with_sandbox("true") do
      assert seller.approvable_account?
      seller.approve!(kyc_level_6_confirmed: true)
    end

    assert_predicate seller.reload, :approved?
  end

  # A configuração ausente não afrouxa nada: fora do sandbox a recusa é a
  # mesma de antes, e sem o KYC confirmado nem o sandbox aprova.
  test "sandbox mode does not waive the KYC confirmation" do
    seller = Seller.create!(name: "Ateliê sem KYC", owner_full_name: "Ana Lua", cpf: "12345678909")
    seller.connect_mercado_pago!(mercado_pago_credentials(live_mode: false, test_account: true))

    with_sandbox("true") do
      assert_raises(Seller::VerificationRequired) { seller.approve!(kyc_level_6_confirmed: false) }
    end

    with_sandbox(nil) do
      assert_not seller.approvable_account?
      assert_raises(Seller::VerificationRequired) { seller.approve!(kyc_level_6_confirmed: true) }
    end

    assert_predicate seller.reload, :pending?
  end

  test "approves a real account with KYC confirmed" do
    seller = Seller.create!(name: "Ateliê real", owner_full_name: "Ana Lua", cpf: "98765432100")
    seller.connect_mercado_pago!(mercado_pago_credentials(live_mode: true, test_account: false))

    seller.approve!(kyc_level_6_confirmed: true)

    assert seller.reload.approved?
  end

  test "disconnecting clears the account type" do
    seller = Seller.create!(name: "Ateliê desconecta", owner_full_name: "Ana Lua", cpf: "13579246828")
    seller.connect_mercado_pago!(mercado_pago_credentials(test_account: false))
    seller.disconnect_mercado_pago!

    assert_nil seller.reload.mercado_pago_test_account
  end

  test "getting_started_steps reflects address, Mercado Pago, PIX key, first product and approval" do
    seller = Seller.create!(name: "Ateliê dos passos", owner_full_name: "Ana Passos", cpf: "11144477735")

    assert_equal({ address: false, mercado_pago: false, pix_key: false, product: false, approval: false }, seller.getting_started_steps)

    seller.update!(
      origin_zip_code: "01310100", origin_street: "Avenida Paulista", origin_number: "1000",
      origin_neighborhood: "Bela Vista", origin_city: "São Paulo", origin_state: "SP",
      mercado_pago_user_id: "123456", mercado_pago_access_token_ciphertext: "a", mercado_pago_refresh_token_ciphertext: "r",
      mercado_pago_connected_at: Time.current, status: :approved, approved_at: Time.current,
      pix_key_confirmed_at: Time.current
    )
    seller.products.create!(name: "Primeira peça", sku: "PASSOS-1", price_cents: 5_000, stock_quantity: 1)

    assert_equal({ address: true, mercado_pago: true, pix_key: true, product: true, approval: true }, seller.getting_started_steps)
  end

  test "setup_steps keeps a connected but not accepted Mercado Pago account as pending" do
    seller = Seller.create!(name: "Ateliê não aceito", owner_full_name: "Ana Aceite", cpf: "11144477735")
    seller.update!(
      mercado_pago_user_id: "123456", mercado_pago_access_token_ciphertext: "a", mercado_pago_refresh_token_ciphertext: "r",
      mercado_pago_connected_at: Time.current, mercado_pago_live_mode: false, mercado_pago_test_account: true
    )

    assert seller.getting_started_steps[:mercado_pago], "a página Primeiros passos vê a conexão"
    assert_not seller.setup_steps[:mercado_pago], "o painel cobra a conta real"

    seller.update!(mercado_pago_live_mode: true, mercado_pago_test_account: false)
    assert seller.setup_steps[:mercado_pago]
  end

  test "public_page_available? is true only for an approved seller that is not hidden" do
    seller = Seller.create!(name: "Ateliê da página", owner_full_name: "Ana Página", cpf: "11144477735")
    assert_not seller.public_page_available?, "pendente responde 404"

    seller.update!(status: :approved, approved_at: Time.current)
    assert seller.public_page_available?

    seller.hide!
    assert_not seller.public_page_available?, "escondido tem página de indisponível"

    seller.unhide!
    seller.update!(status: :suspended)
    assert_not seller.public_page_available?, "suspenso tem página de indisponível"
  end

  test "theme images accept png, jpeg and webp up to 5MB" do
    seller = sellers(:approved)
    seller.logo.attach(io: StringIO.new("img"), filename: "logo.png", content_type: "image/png")
    seller.cover_image.attach(io: StringIO.new("img"), filename: "capa.webp", content_type: "image/webp")

    assert_predicate seller, :valid?
  end

  test "theme images reject other content types and files over 5MB" do
    seller = sellers(:approved)
    seller.logo.attach(io: StringIO.new("<svg/>"), filename: "logo.svg", content_type: "image/svg+xml")
    seller.cover_image.attach(io: StringIO.new("x" * (Seller::THEME_IMAGE_MAX_BYTES + 1)), filename: "capa.png", content_type: "image/png")

    assert_not_predicate seller, :valid?
    assert_includes seller.errors[:logo].join, "PNG, JPEG ou WEBP"
    assert_includes seller.errors[:cover_image].join, "5MB"
  end

  test "footer_text is stripped, blank becomes nil and is capped" do
    seller = sellers(:approved)
    seller.footer_text = "  Feito à mão.  "
    assert_equal "Feito à mão.", seller.footer_text

    seller.footer_text = "   "
    assert_nil seller.footer_text

    seller.footer_text = "a" * (Seller::FOOTER_TEXT_MAX_LENGTH + 1)
    assert_not_predicate seller, :valid?
  end

  test "theme options default to the original storefront look and accept only catalog keys" do
    seller = sellers(:approved)
    assert_equal SellerTheme::DEFAULTS[:palette], seller.theme_palette
    assert_equal SellerTheme::DEFAULTS[:layout], seller.theme_layout

    seller.theme_palette = "neon"
    assert_not seller.valid?
    assert seller.errors[:theme_palette].any?

    seller.theme_palette = "oceano"
    seller.valid?
    assert_empty seller.errors[:theme_palette]
  end

  test "every preset sets every theme option, and only to existing keys" do
    SellerTheme::PRESETS.each do |key, preset|
      assert SellerTheme::PALETTES.key?(preset[:palette]), key
      assert SellerTheme::FONTS.key?(preset[:font]), key
      assert SellerTheme::LAYOUTS.key?(preset[:layout]), key
      assert SellerTheme::HEROES.key?(preset[:hero]), key
      assert SellerTheme::CORNERS.key?(preset[:corners]), key
      assert SellerTheme::CARD_STYLES.key?(preset[:card_style]), key
      assert SellerTheme::BACKGROUNDS.key?(preset[:background]), key
      assert SellerTheme::ORNAMENTS.key?(preset[:ornament]), key
      assert SellerTheme::IMAGE_RATIOS.key?(preset[:image_ratio]), key
      assert SellerTheme::HEADING_FONTS.key?(preset[:heading_font]), key
    end
  end

  # O editor aplica cada chave do tema como um campo `theme_<chave>`: uma
  # chave sem coluna seria ignorada em silêncio.
  test "every preset key maps to a seller theme column" do
    SellerTheme::PRESETS.each_value do |preset|
      (preset.keys - [ :label ]).each { |key| assert Seller.column_names.include?("theme_#{key}"), key }
    end
  end

  test "background, ornament and photo ratio default to the plain storefront and accept only catalog keys" do
    seller = sellers(:approved)
    assert_equal "branco", seller.theme_background
    assert_equal "nenhum", seller.theme_ornament
    assert_equal "quadrada", seller.theme_image_ratio

    seller.assign_attributes(theme_background: "neon", theme_ornament: "url(evil)", theme_image_ratio: "16:9")
    assert_not seller.valid?
    assert seller.errors[:theme_background].any?
    assert seller.errors[:theme_ornament].any?
    assert seller.errors[:theme_image_ratio].any?
  end

  test "heading font defaults to the text font and accepts only catalog keys" do
    seller = sellers(:approved)
    assert_equal "igual", seller.theme_heading_font
    assert_includes SellerTheme.css_variables(palette: "oliva", font: "classica"), "--atelier-heading-font:var(--atelier-font)"

    seller.theme_heading_font = "Comic Sans; color:red"
    assert_not seller.valid?
    assert seller.errors[:theme_heading_font].any?
  end

  # A CSP só admite fonte do próprio app: cada fonte de título precisa de um
  # @font-face com o arquivo em app/assets/fonts, ou cairia no fallback.
  test "every custom heading font is self-hosted" do
    css = Rails.root.join("app/assets/tailwind/application.css").read
    SellerTheme::HEADING_FONTS.each_value do |heading|
      next unless heading[:stack]

      family = heading[:stack][/\A'([^']+)'/, 1]
      face = css[/@font-face \{[^}]*font-family: "#{family}";[^}]*\}/]
      assert face, "#{family}: falta @font-face"
      file = face[/url\("([^"]+)"\)/, 1]
      assert Rails.root.join("app/assets/fonts", file).exist?, "#{family}: falta #{file}"
    end
  end

  # No fundo escuro (o início do degradê misturado a quase preto), o destaque
  # vira o tom claro da paleta; ele e os textos claros do `atelier-dark`
  # precisam do contraste AA, também sobre o card com fundo.
  test "the dark background keeps page text readable for every palette" do
    mix = ->(color, share, base) do
      color.delete("#").scan(/../).zip(base.delete("#").scan(/../))
           .map { |a, b| format("%02x", (a.to_i(16) * share + b.to_i(16) * (1 - share)).round) }.join.prepend("#")
    end
    SellerTheme::PALETTES.each do |key, palette|
      page = mix.(palette[:from], SellerTheme::DARK_FROM_SHARE / 100.0, SellerTheme::DARK_BASE)
      card = mix.(palette[:to], 0.22, "#1c1917")
      [ palette[:soft], "#f5f1ec", "#c9c2b9" ].each do |text|
        assert_operator SellerTheme.contrast_ratio(text, page), :>=, 4.5, "#{key}: #{text} na página"
        assert_operator SellerTheme.contrast_ratio(text, card), :>=, 4.5, "#{key}: #{text} no card"
      end
    end
  end

  test "the dark background swaps the on-page accent and the card tone" do
    light = SellerTheme.css_variables(palette: "oliva", font: "moderna", background: "branco")
    dark = SellerTheme.css_variables(palette: "oliva", font: "moderna", background: "escuro")

    assert_includes light, "--atelier-accent-on-page:var(--atelier-accent)"
    assert_includes dark, "--atelier-accent-on-page:var(--atelier-soft)"
    assert_not_equal light[/--atelier-card:[^;]*/], dark[/--atelier-card:[^;]*/]
    assert SellerTheme.dark?("escuro")
    assert_not SellerTheme.dark?("papel")
  end

  test "the plain background and no ornament add no styles" do
    assert_nil SellerTheme.page_background_style("branco")
    assert_nil SellerTheme.ornament_style("nenhum")
    assert_nil SellerTheme.ornament_style("desconhecido")
  end

  # O SVG vai inteiro codificado dentro de `url()`: aspas, `#` ou parênteses
  # soltos fechariam a declaração antes da hora.
  test "textures and ornaments are fully encoded data URIs" do
    styles = SellerTheme::BACKGROUNDS.keys.filter_map { |key| SellerTheme.page_background_style(key) } +
             SellerTheme::ORNAMENTS.keys.filter_map { |key| SellerTheme.ornament_style(key) }
    urls = styles.flat_map { |style| style.scan(/url\(([^)]*)\)/).flatten }

    assert_not_empty urls
    urls.each do |url|
      assert url.start_with?("data:image/svg+xml,%3Csvg"), url
      assert_no_match(/["'#<> ]/, url)
    end
  end

  # O filtro do editor não pode esconder um tema de vez nem apontar para um
  # tema que não existe.
  test "preset filters point to existing presets and reach every preset" do
    SellerTheme::PRESET_CATEGORIES.each do |key, category|
      assert_not_empty category[:presets], key
      category[:presets].each { |preset| assert SellerTheme::PRESETS.key?(preset), "#{key}: #{preset}" }
    end
    SellerTheme::PRESETS.each_key { |key| assert_not_empty SellerTheme.preset_filters(key), key }
  end

  test "dark presets also fall under the dark background filter" do
    assert_includes SellerTheme.preset_filters("luz_de_vela"), "bem_estar"
    assert_includes SellerTheme.preset_filters("luz_de_vela"), SellerTheme::DARK_PRESETS_FILTER
    assert_not_includes SellerTheme.preset_filters("ciranda"), SellerTheme::DARK_PRESETS_FILTER
  end

  test "presets have distinct names" do
    labels = SellerTheme::PRESETS.values.pluck(:label)
    assert_equal labels.uniq, labels
  end

  # O texto branco do topo cai sobre o fim do degradê (`to`) e o da faixa de
  # aviso sobre o `accent`: as duas cores seguem a mesma regra da cor própria.
  test "every palette keeps white text readable on its accent and gradient end" do
    SellerTheme::PALETTES.each do |key, palette|
      assert_operator SellerTheme.contrast_ratio(palette[:accent]), :>=, SellerTheme::MIN_ACCENT_CONTRAST, "#{key}: accent"
      assert_operator SellerTheme.contrast_ratio(palette[:to]), :>=, SellerTheme::MIN_ACCENT_CONTRAST, "#{key}: to"
    end
  end
end
