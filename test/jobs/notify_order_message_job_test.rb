require "test_helper"

class NotifyOrderMessageJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @seller_order = seller_orders(:one)
    @seller_order.update!(status: :confirmed)
    @seller_order.order.update!(status: :confirmed)
  end

  test "notifies the seller when the customer writes" do
    message = @seller_order.order_messages.create!(sender: customers(:one), body: "Olá, ateliê!")

    assert_emails 1 do
      NotifyOrderMessageJob.perform_now(message)
    end

    email = ActionMailer::Base.deliveries.last
    assert_includes email.to, users(:seller).email_address
    assert_includes email.subject, "pedido ##{@seller_order.order_id}"
  end

  test "notifies the customer when the seller writes" do
    message = @seller_order.order_messages.create!(sender: users(:seller), body: "Olá, cliente!")

    assert_emails 1 do
      NotifyOrderMessageJob.perform_now(message)
    end

    assert_includes ActionMailer::Base.deliveries.last.to, customers(:one).email
  end

  test "does not fail when the seller has no user" do
    seller = Seller.create!(name: "Ateliê sem acesso #{SecureRandom.hex(4)}", owner_full_name: "Dono Sem Acesso",
      cpf: "35720194606", status: :approved, approved_at: Time.current)
    @seller_order.update!(seller: seller)
    message = @seller_order.order_messages.create!(sender: customers(:one), body: "Olá?")

    assert_no_emails do
      assert_nothing_raised { NotifyOrderMessageJob.perform_now(message) }
    end
  end
end
