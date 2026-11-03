require "test_helper"

# Toda movimentação avisa todos os envolvidos menos quem agiu (ADR 008).
class ReturnRequests::NotificationsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @seller_order = seller_orders(:one)
    @seller_order.update!(status: :confirmed)
    @customer = customers(:one)
    @seller = @seller_order.seller
    @admin = users(:one)
    @other_admin = users(:two)
  end

  test "opening reaches the buyer, the atelier and every admin" do
    return_request = open_request(kind: :withdrawal)

    assert_equal 1, notifications_for(@customer, return_request).count
    assert_equal 1, notifications_for(@seller, return_request).count
    User.admin.each { |admin| assert_equal 1, notifications_for(admin, return_request).count, admin.email_address }
  end

  test "a buyer message reaches the admins and the atelier, not the buyer" do
    return_request = open_request(kind: :withdrawal)

    assert_no_difference -> { Notification.where(recipient: @customer).count } do
      assert_difference -> { Notification.where(recipient: @seller).count } => 1,
                        -> { Notification.where(recipient_type: "User").count } => User.admin.count do
        ReturnRequests::Open.new(seller_order: @seller_order, customer: @customer, kind: :withdrawal, description: "Mais detalhes.").call
      end
    end
    assert_match "Nova mensagem em #{return_request.protocol}", Notification.where(recipient: @seller).last.title
  end

  test "an admin answer reaches the buyer, the atelier and the other admins, not the admin who answered" do
    return_request = open_request(kind: :product_issue)
    update = return_request.record_update!(author: @admin, body: "Pode mandar fotos?")

    # Comprador e ateliê; admins só no painel.
    assert_enqueued_emails 2 do
      assert_no_difference -> { Notification.where(recipient: @admin).count } do
        assert_difference -> { Notification.where(recipient: @other_admin).count } => 1,
                          -> { Notification.where(recipient: @customer).count } => 1,
                          -> { Notification.where(recipient: @seller).count } => 1 do
          ReturnRequests::Notifications.updated(update)
        end
      end
    end
    assert_match "respondeu ao comprador", Notification.where(recipient: @seller).last.body
    assert_match @admin.email_address, Notification.where(recipient: @other_admin).last.body
  end

  test "closing a withdrawal before shipping tells the atelier that shipping is unlocked" do
    return_request = open_request(kind: :withdrawal)
    update = return_request.record_update!(author: @admin, new_status: "closed")

    ReturnRequests::Notifications.updated(update)

    seller_notification = Notification.where(recipient: @seller, kind: "return_request_updated").last
    assert_match "Encerrada", seller_notification.body
    assert_match "O envio está liberado", seller_notification.body
  end

  test "a status change that keeps the withdrawal open does not unlock shipping" do
    return_request = open_request(kind: :withdrawal)
    update = return_request.record_update!(author: @admin, new_status: "in_progress")

    ReturnRequests::Notifications.updated(update)

    seller_notification = Notification.where(recipient: @seller, kind: "return_request_updated").last
    assert_match "Em andamento", seller_notification.body
    assert_no_match "O envio está liberado", seller_notification.body
  end

  test "the atelier gets the same notice by e-mail, at its first user" do
    return_request = open_request(kind: :withdrawal)
    update = return_request.record_update!(author: @admin, new_status: "closed")

    assert_enqueued_email_with ReturnRequestMailer, :seller_notice,
      args: [ return_request, users(:seller).email_address, "Solicitação #{return_request.protocol} encerrada",
              "A EloShop mudou a solicitação do pedido ##{return_request.order.id} (desistência da compra) para \"Encerrada\". O envio está liberado." ] do
      ReturnRequests::Notifications.updated(update)
    end
  end

  test "an atelier without users still gets the panel notice, without e-mail" do
    @seller.users.each { |user| user.update_columns(seller_id: nil, role: "admin") }
    return_request = nil

    assert_enqueued_emails 1 do # só o do comprador
      return_request = open_request(kind: :product_issue)
    end
    assert Notification.exists?(recipient: @seller, kind: "return_request_opened")
    assert return_request.persisted?
  end

  private

  def open_request(kind:)
    ReturnRequests::Open.new(seller_order: @seller_order, customer: @customer, kind: kind).call.return_request
  end

  def notifications_for(recipient, return_request)
    Notification.where(recipient: recipient).where("title LIKE ? OR body LIKE ?", "%#{return_request.protocol}%", "%##{return_request.order.id}%")
  end
end
