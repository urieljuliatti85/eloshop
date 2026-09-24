require "test_helper"

module SellerPortal
  class OrderMessagesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @order = orders(:one)
      @order.update!(status: :confirmed)
      @order.seller_order.update!(status: :confirmed)
    end

    test "seller sees paid orders in the message inbox" do
      sign_in_as(users(:seller))

      get seller_messages_path

      assert_response :success
      assert_select "a[href='#{seller_order_messages_path(@order)}']"
    end

    test "seller sends a message as the authenticated seller user" do
      sign_in_as(users(:seller))

      assert_enqueued_with(job: NotifyOrderMessageJob) do
        assert_difference("OrderMessage.count", 1) do
          post seller_order_messages_path(@order), params: { order_message: { body: "Seu pedido ficará pronto amanhã." } }
        end
      end

      message = OrderMessage.order(:created_at).last
      assert_equal users(:seller), message.sender
      assert_redirected_to seller_order_messages_path(@order)

      notification = @order.customer.notifications.new_message.last
      assert notification.present?
      assert_equal order_path(@order), notification.url
    end

    test "seller cannot access another seller's conversation" do
      @order.seller_order.update!(seller: sellers(:other))
      sign_in_as(users(:seller))

      get seller_order_messages_path(@order)

      assert_response :not_found
    end

    test "admin cannot use the seller message inbox" do
      sign_in_as(users(:one))

      get seller_messages_path

      assert_redirected_to seller_login_path
    end

    test "conversation is unavailable before payment confirmation" do
      @order.update!(status: :pending)
      @order.seller_order.update!(status: :pending)
      sign_in_as(users(:seller))

      get seller_order_messages_path(@order)

      assert_redirected_to seller_messages_path
    end
  end
end
