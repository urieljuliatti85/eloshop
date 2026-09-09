require "test_helper"

class SellerTest < ActiveSupport::TestCase
  test "assigns a slug and starts pending" do
    seller = Seller.create!(name: "Ateliê da Lua")

    assert_equal "atelie-da-lua", seller.slug
    assert_predicate seller, :pending?
    assert_nil seller.approved_at
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

    assert_raises(Seller::VerificationRequired) do
      seller.approve!(kyc_level_6_confirmed: true)
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

  private

  # `test_account: false` é o padrão porque a maioria dos casos descreve uma
  # conta real; os testes de conta de teste passam `true` explicitamente.
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
    assert Seller.new(name: "Sem endereço").valid?
  end

  test "requires the whole origin address once one field is filled" do
    seller = Seller.new(name: "Parcial", origin_city: "Florianópolis")

    assert_not seller.valid?
    assert seller.origin_address_started?
    assert_not seller.origin_address_complete?
  end

  test "accepts a complete origin address" do
    seller = Seller.new(name: "Completo", origin_zip_code: "88010-000", origin_street: "Rua A",
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
    seller = Seller.create!(name: "Ateliê de teste")
    seller.connect_mercado_pago!(mercado_pago_credentials(live_mode: true, test_account: true))

    assert seller.mercado_pago_connected?
    assert seller.mercado_pago_live_mode?
    assert_not seller.mercado_pago_real_account?
    assert_raises(Seller::VerificationRequired) { seller.approve!(kyc_level_6_confirmed: true) }
  end

  # Sem certeza sobre a conta, a aprovação não passa: aprovar no escuro é o
  # risco que a salvaguarda existe para evitar.
  test "refuses approval when the account type is unknown" do
    seller = Seller.create!(name: "Ateliê indefinido")
    seller.connect_mercado_pago!(mercado_pago_credentials(live_mode: true, test_account: nil))

    assert_nil seller.mercado_pago_test_account
    assert_not seller.mercado_pago_real_account?
    assert_raises(Seller::VerificationRequired) { seller.approve!(kyc_level_6_confirmed: true) }
  end

  test "approves a real account with KYC confirmed" do
    seller = Seller.create!(name: "Ateliê real")
    seller.connect_mercado_pago!(mercado_pago_credentials(live_mode: true, test_account: false))

    seller.approve!(kyc_level_6_confirmed: true)

    assert seller.reload.approved?
  end

  test "disconnecting clears the account type" do
    seller = Seller.create!(name: "Ateliê desconecta")
    seller.connect_mercado_pago!(mercado_pago_credentials(test_account: false))
    seller.disconnect_mercado_pago!

    assert_nil seller.reload.mercado_pago_test_account
  end
end
