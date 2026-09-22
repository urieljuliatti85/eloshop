require "test_helper"

class OrderMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @order = orders(:one)
    @order.update!(status: :confirmed)
    @order.seller_order.update!(status: :confirmed)
  end

  test "redirects an unauthenticated visitor to customer login" do
    get order_messages_path(@order)

    assert_redirected_to new_customer_session_path
  end

  test "customer sees the conversation for their paid order" do
    sign_in_customer(customers(:one))

    get order_messages_path(@order)

    assert_response :success
    assert_select "h1", text: /Conversa com/
  end

  test "customer sends a message as themself and schedules the notification" do
    sign_in_customer(customers(:one))

    assert_enqueued_with(job: NotifyOrderMessageJob) do
      assert_difference("OrderMessage.count", 1) do
        post order_messages_path(@order), params: { order_message: { body: "Pode embrulhar para presente?" } }
      end
    end

    message = OrderMessage.order(:created_at).last
    assert_equal customers(:one), message.sender
    assert_redirected_to order_messages_path(@order)
  end

  test "customer cannot access another customer's conversation" do
    sign_in_customer(customers(:two))

    get order_messages_path(@order)

    assert_response :not_found
  end

  test "conversation is unavailable before payment confirmation" do
    @order.update!(status: :pending)
    @order.seller_order.update!(status: :pending)
    sign_in_customer(customers(:one))

    get order_messages_path(@order)

    assert_redirected_to order_path(@order)
  end

  test "message body is escaped in the conversation" do
    @order.seller_order.order_messages.create!(sender: customers(:one), body: "<script>alert('x')</script>")
    sign_in_customer(customers(:one))

    get order_messages_path(@order)

    assert_response :success
    assert_select "script", text: /alert\('x'\)/, count: 0
    assert_includes response.body, "&lt;script&gt;"
  end

  private

  def sign_in_customer(customer)
    post customer_session_path, params: { email: customer.email, password: "password123" }
  end
end
