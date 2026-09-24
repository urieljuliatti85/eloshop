require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:one)
  end

  test "starts unread and can be marked as read" do
    notification = Notification.create!(
      recipient: @customer, kind: :order_confirmed, title: "Pagamento confirmado", body: "Seu pedido foi confirmado."
    )

    assert_not notification.read?
    assert_includes @customer.notifications.unread, notification

    notification.mark_as_read!

    assert notification.read?
    assert_not_includes @customer.notifications.unread, notification
  end

  test "marking an already read notification as read again is a no-op" do
    notification = Notification.create!(
      recipient: @customer, kind: :new_message, title: "Nova mensagem", body: "Você recebeu uma mensagem."
    )
    notification.mark_as_read!
    read_at = notification.read_at

    notification.mark_as_read!

    assert_equal read_at, notification.reload.read_at
  end

  test "requires kind, title and body" do
    notification = Notification.new(recipient: @customer)

    assert_not notification.valid?
    assert_includes notification.errors[:kind], "can't be blank"
    assert_includes notification.errors[:title], "can't be blank"
    assert_includes notification.errors[:body], "can't be blank"
  end
end
