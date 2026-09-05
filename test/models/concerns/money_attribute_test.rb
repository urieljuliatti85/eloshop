require "test_helper"

class MoneyAttributeTest < ActiveSupport::TestCase
  test "parses brazilian format" do
    assert_equal 4000, MoneyAttribute.to_cents("40,00")
    assert_equal 8990, MoneyAttribute.to_cents("89,90")
    assert_equal 129_990, MoneyAttribute.to_cents("1.299,90")
  end

  test "parses a dot as decimal separator when there is no comma" do
    assert_equal 4000, MoneyAttribute.to_cents("40.00")
    assert_equal 129_990, MoneyAttribute.to_cents("1299.90")
  end

  test "ignores currency symbol and surrounding space" do
    assert_equal 4000, MoneyAttribute.to_cents("R$ 40,00")
    assert_equal 5555, MoneyAttribute.to_cents("  55,55  ")
  end

  test "accepts a whole number as reais" do
    assert_equal 4000, MoneyAttribute.to_cents("40")
  end

  # Um Integer já é a unidade do banco: `Product.new(price_cents: 8990)`
  # e o seed continuam funcionando sem passar pela conversão.
  test "passes an integer through untouched" do
    assert_equal 8990, MoneyAttribute.to_cents(8990)
  end

  # Sem isso o campo opcional em branco viraria 0 — um preço decidido, e não
  # a ausência de decisão.
  test "returns nil for blank and for junk" do
    assert_nil MoneyAttribute.to_cents("")
    assert_nil MoneyAttribute.to_cents(nil)
    assert_nil MoneyAttribute.to_cents("abc")
  end

  # A razão de o parsing usar BigDecimal, e não Float.
  test "converts without floating point drift" do
    assert_equal 29, MoneyAttribute.to_cents("0,29")
    assert_equal 4010, MoneyAttribute.to_cents("40,10")
    assert_equal 1_070, MoneyAttribute.to_cents("10,70")
  end

  test "exposes the value back in reais" do
    product = Product.new(price_cents: 8990)

    assert_equal 89.9, product.price.to_f
  end

  test "round trips through the writer" do
    product = Product.new
    product.price = "1.299,90"

    assert_equal 129_990, product.price_cents
  end

  test "coupon optional amount stays nil when left blank" do
    coupon = Coupon.new
    coupon.minimum_subtotal = ""

    assert_nil coupon.minimum_subtotal_cents
  end
end
