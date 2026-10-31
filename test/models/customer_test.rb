require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "invalid without name" do
    customer = Customer.new(email: "new@example.com", password: "password123")
    assert_not customer.valid?
    assert_includes customer.errors[:name], "não pode ficar em branco"
  end

  test "invalid with duplicate email" do
    duplicate = Customer.new(name: "Outro", email: customers(:one).email, password: "password123")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "já está em uso"
  end

  test "normalizes email" do
    customer = Customer.new(name: "Novo", email: "  New@Example.com  ", password: "password123")
    customer.valid?
    assert_equal "new@example.com", customer.email
  end

  test "authenticate_by returns the customer with correct credentials" do
    assert_equal customers(:one), Customer.authenticate_by(email: customers(:one).email, password: "password123")
  end

  test "authenticate_by returns nil with wrong password" do
    assert_nil Customer.authenticate_by(email: customers(:one).email, password: "wrong")
  end

  test "email availability ignores case and spaces when looking for an existing account" do
    assert_equal({ valid: true, available: false }, Customer.email_availability("  MARIA@Example.com "))
    assert_equal({ valid: true, available: true }, Customer.email_availability("livre@example.com"))
  end

  test "email availability rejects what is not an e-mail address" do
    [ "", "sem-arroba", "a@", "@b.com", "dois @example.com", "isso@nao" ].each do |value|
      assert_equal({ valid: false, available: false }, Customer.email_availability(value), value.inspect)
    end
  end
end
