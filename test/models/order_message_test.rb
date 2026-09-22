require "test_helper"

class OrderMessageTest < ActiveSupport::TestCase
  setup do
    @seller_order = seller_orders(:one)
    @seller_order.update!(status: :confirmed)
    @seller_order.order.update!(status: :confirmed)
  end

  test "accepts the order customer as sender" do
    message = @seller_order.order_messages.new(sender: customers(:one), body: "Quando será enviado?")

    assert message.valid?
  end

  test "accepts a user from the order seller as sender" do
    message = @seller_order.order_messages.new(sender: users(:seller), body: "Seu pedido está em produção.")

    assert message.valid?
  end

  test "rejects people who do not participate in the order" do
    customer_message = @seller_order.order_messages.new(sender: customers(:two), body: "Mensagem indevida")
    admin_message = @seller_order.order_messages.new(sender: users(:one), body: "Mensagem indevida")

    assert_not customer_message.valid?
    assert_includes customer_message.errors[:sender], "não participa deste pedido"
    assert_not admin_message.valid?
    assert_includes admin_message.errors[:sender], "não participa deste pedido"
  end

  test "rejects messages before payment confirmation" do
    @seller_order.update!(status: :pending)
    message = @seller_order.order_messages.new(sender: customers(:one), body: "Mensagem antecipada")

    assert_not message.valid?
    assert_includes message.errors[:seller_order], "só aceita mensagens depois da confirmação do pagamento"
  end

  test "keeps the conversation available after a refund" do
    @seller_order.update!(status: :refunded)

    assert @seller_order.accepts_messages?
  end

  test "limits the message body" do
    message = @seller_order.order_messages.new(sender: customers(:one), body: "a" * 2_001)

    assert_not message.valid?
    assert message.errors[:body].present?
  end
end
