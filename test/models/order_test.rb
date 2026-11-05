require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "keeps the recipient CPF encrypted and shows it masked" do
    order = orders(:one)
    order.update!(recipient_cpf: "529.982.247-25")

    assert_not_includes order.recipient_cpf_ciphertext, "52998224725"
    assert_equal "52998224725", order.reload.recipient_cpf
    assert_equal "***.***.***-25", order.masked_recipient_cpf

    order.update!(recipient_cpf: "")
    assert_nil order.reload.recipient_cpf_ciphertext
    assert_nil order.masked_recipient_cpf
  end

  test "orders from before the recipient step show the buyer as recipient" do
    order = orders(:one)
    order.update!(recipient_name: nil)
    assert_equal order.customer.name, order.recipient_display_name

    order.update!(recipient_name: "Ana Souza")
    assert_equal "Ana Souza", order.recipient_display_name
  end

  test "invalid with duplicate idempotency_key" do
    duplicate = Order.new(orders(:one).attributes.except("id").merge("idempotency_key" => orders(:two).idempotency_key))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:idempotency_key], "já está em uso"
  end

  test "invalid without shipping_address_snapshot" do
    order = Order.new(orders(:one).attributes.except("id", "shipping_address_snapshot", "idempotency_key"))
    assert_not order.valid?
    assert_includes order.errors[:shipping_address_snapshot], "não pode ficar em branco"
  end

  test "invalid with negative totals" do
    order = Order.new(orders(:one).attributes.except("id", "idempotency_key").merge("total_cents" => -1))
    assert_not order.valid?
    assert_includes order.errors[:total_cents], "deve ser maior ou igual a 0"
  end

  test "confirm! transitions pending to confirmed" do
    order = orders(:one)
    order.confirm!
    assert order.confirmed?
  end

  test "cancel! transitions pending to cancelled" do
    order = orders(:one)
    order.cancel!
    assert order.cancelled?
  end

  test "cancel! transitions confirmed to cancelled" do
    order = orders(:one)
    order.confirm!
    order.cancel!
    assert order.cancelled?
  end

  test "cancelled is a terminal state" do
    order = orders(:one)
    order.cancel!

    assert_raises(Order::InvalidStatusTransition) { order.confirm! }
    assert_raises(Order::InvalidStatusTransition) { order.cancel! }
  end
end
