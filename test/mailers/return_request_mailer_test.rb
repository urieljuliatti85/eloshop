require "test_helper"

class ReturnRequestMailerTest < ActionMailer::TestCase
  setup do
    seller_order = seller_orders(:one)
    seller_order.update!(status: :confirmed)
    @return_request = ReturnRequests::Open.new(
      seller_order: seller_order, customer: customers(:one), kind: :withdrawal, description: "Mudei de ideia."
    ).call.return_request
  end

  test "opened sends the protocol, the deadline and the link to the buyer" do
    email = ReturnRequestMailer.opened(@return_request)

    assert_equal [ @return_request.order.customer.email ], email.to
    assert_match @return_request.protocol, email.subject
    [ email.html_part.body.to_s, email.text_part.body.to_s ].each do |body|
      assert_match @return_request.protocol, body
      assert_match I18n.l(@return_request.respond_by, format: :short), body
      assert_match "Mudei de ideia.", body
      assert_match "/orders/#{@return_request.order.id}/solicitacoes/#{@return_request.id}", body
    end
  end

  test "updated sends the new status and the answer" do
    update = @return_request.record_update!(author: users(:one), body: "Reembolso solicitado.", new_status: "resolved")

    email = ReturnRequestMailer.updated(update)

    [ email.html_part.body.to_s, email.text_part.body.to_s ].each do |body|
      assert_match "Resolvida", body
      assert_match "Reembolso solicitado.", body
    end
  end

  test "seller_notice tells the atelier what happened and links to the order in the panel" do
    email = ReturnRequestMailer.seller_notice(@return_request, "atelie@example.com", "Desistência no pedido", "Não envie a peça.")

    assert_equal [ "atelie@example.com" ], email.to
    assert_equal "Desistência no pedido — EloShop", email.subject
    [ email.html_part.body.to_s, email.text_part.body.to_s ].each do |body|
      assert_match "Não envie a peça.", body
      assert_match @return_request.protocol, body
      assert_match "/painel/orders/#{@return_request.order.id}", body
    end
  end
end
