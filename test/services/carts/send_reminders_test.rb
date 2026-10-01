require "test_helper"

module Carts
  class SendRemindersTest < ActiveSupport::TestCase
    include ActionMailer::TestHelper

    setup do
      @customer = Customer.create!(name: "Cliente", email: "lembrete-#{SecureRandom.hex(4)}@example.com", password: "password123")
      @product = Product.create!(seller: sellers(:approved), name: "Peça lembrada", sku: "REM-#{SecureRandom.hex(4)}",
        price_cents: 5_000, stock_quantity: 5, currency: "BRL", status: "active")
    end

    def abandoned_cart(idle_for: 25.hours, customer: @customer)
      cart = Cart.create!(session_token: SecureRandom.hex(10), customer: customer)
      item = cart.cart_items.create!(product: @product, quantity: 1)
      item.update_columns(updated_at: idle_for.ago)
      cart
    end

    test "sends one reminder to a logged-in customer whose cart sat idle for a day" do
      cart = abandoned_cart

      assert_enqueued_emails(1) { SendReminders.new.call }

      assert cart.reload.reminder_sent_at.present?
    end

    test "does not remind before 24 hours, nor twice for the same abandonment" do
      recent = abandoned_cart(idle_for: 2.hours)
      assert_no_enqueued_emails { SendReminders.new.call }
      assert_nil recent.reload.reminder_sent_at

      abandoned_cart
      assert_enqueued_emails(1) { SendReminders.new.call }
      assert_no_enqueued_emails { SendReminders.new.call }
    end

    test "reminds again only after new activity in the cart goes idle again" do
      cart = abandoned_cart
      SendReminders.new.call
      cart.cart_items.first.update_columns(updated_at: 25.hours.ago + 1.hour) # atividade depois do lembrete
      cart.update_columns(reminder_sent_at: 26.hours.ago)

      assert_enqueued_emails(1) { SendReminders.new.call }
    end

    test "skips anonymous carts, opted-out customers and carts idle for over a week" do
      Cart.create!(session_token: SecureRandom.hex(10)).cart_items.create!(product: @product, quantity: 1).update_columns(updated_at: 25.hours.ago)
      opted_out = Customer.create!(name: "Recusou", email: "recusou-#{SecureRandom.hex(4)}@example.com", password: "password123", cart_reminder_emails: false)
      abandoned_cart(customer: opted_out)
      abandoned_cart(idle_for: 8.days)

      assert_no_enqueued_emails { SendReminders.new.call }
    end

    test "skips a customer who already ordered after the last cart activity" do
      cart = abandoned_cart
      Order.create!(
        customer: @customer, subtotal_cents: 5_000, shipping_cents: 0, discount_cents: 0, total_cents: 5_000,
        shipping_address_snapshot: { "street" => "Rua" }, idempotency_key: SecureRandom.hex(10)
      )

      assert_no_enqueued_emails { SendReminders.new.call }
      assert_nil cart.reload.reminder_sent_at
    end

    test "skips a cart whose items can no longer be bought" do
      abandoned_cart
      @product.update_columns(status: "draft")

      assert_no_enqueued_emails { SendReminders.new.call }
    end

    test "the periodic job runs the service" do
      abandoned_cart

      assert_enqueued_emails(1) { SendCartRemindersJob.perform_now }
    end
  end
end
