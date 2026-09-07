require "test_helper"

class MercadoPagoTestAccountTest < ActiveSupport::TestCase
  test "encrypts the password at rest and decrypts it back" do
    account = MercadoPagoTestAccount.create!(account_type: "buyer", label: "Comprador BR", password: "s3gredo")

    assert_equal "s3gredo", account.password
    assert_not_includes account.password_ciphertext, "s3gredo"
  end

  test "password is nil when never set" do
    account = MercadoPagoTestAccount.create!(account_type: "seller", label: "Vendedor BR")

    assert_nil account.password
  end

  test "requires account_type and label" do
    account = MercadoPagoTestAccount.new

    assert_not account.valid?
    assert_includes account.errors.attribute_names, :account_type
    assert_includes account.errors.attribute_names, :label
  end

  test "account_type accepts only buyer, seller or marketplace" do
    assert_raises(ArgumentError) do
      MercadoPagoTestAccount.new(account_type: "invalid")
    end
  end
end
