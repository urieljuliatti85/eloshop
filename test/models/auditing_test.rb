require "test_helper"

# Trilha de auditoria (PaperTrail): quem mudou o quê, sem segredos nem ruído.
class AuditingTest < ActiveSupport::TestCase
  setup { PaperTrail.request.whodunnit = nil }

  test "seller status changes are versioned with the author" do
    seller = sellers(:approved)
    PaperTrail.request.whodunnit = "42"

    seller.hide!

    version = seller.versions.last
    assert_equal "update", version.event
    assert_equal "42", version.whodunnit
    assert_includes version.object_changes.keys, "hidden_at"
  end

  test "changes made outside a user session have no author" do
    seller = sellers(:approved)

    seller.hide!

    assert_nil seller.versions.last.whodunnit
  end

  test "seller tokens, cpf and address never reach the versions table" do
    seller = Seller.create!(name: "Ateliê Auditado", owner_full_name: "Ana Lua", cpf: "11144477735")
    seller.connect_mercado_pago!(Marketplace::MercadoPagoOauth::Credentials.new(
      user_id: "mp-auditado", access_token: "segredo-access", refresh_token: "segredo-refresh",
      expires_at: 180.days.from_now, live_mode: true, test_account: false, public_key: "APP_USR-public"
    ))
    seller.update!(origin_street: "Rua Privada", origin_number: "10", origin_neighborhood: "Centro",
                   origin_city: "São Paulo", origin_state: "SP", origin_zip_code: "01001000")

    dump = seller.versions.map { |v| v.object_changes.to_json }.join
    assert_no_match(/segredo-|ciphertext|cpf|Rua Privada|11144477735/, dump)
  end

  test "product stock changes are not versioned but price changes are" do
    product = Product.first

    assert_no_difference -> { product.versions.count } do
      product.update!(stock_quantity: product.stock_quantity + 1)
    end

    assert_difference -> { product.versions.count }, 1 do
      product.update!(price_cents: product.price_cents + 100)
    end
  end

  test "coupon usage counter is not versioned" do
    coupon = Coupon.create!(code: "AUDIT#{SecureRandom.hex(4)}", discount_type: "percentage", percentage: 10)

    assert_no_difference -> { coupon.versions.count } do
      coupon.update!(uses_count: coupon.uses_count + 1)
    end
  end
end
