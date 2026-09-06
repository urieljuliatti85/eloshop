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

  test "changing the connected Mercado Pago account requires a new approval" do
    seller = sellers(:approved)

    seller.connect_mercado_pago!(mercado_pago_credentials)

    assert_predicate seller, :pending?
    assert_nil seller.approved_at
  end

  private

  def mercado_pago_credentials(live_mode: true)
    Marketplace::MercadoPagoOauth::Credentials.new(
      user_id: "123456",
      access_token: "seller-access-token",
      refresh_token: "seller-refresh-token",
      expires_at: 180.days.from_now,
      live_mode: live_mode
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
end
