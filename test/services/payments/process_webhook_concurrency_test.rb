require "test_helper"

module Payments
  # Testes de concorrência real precisam de conexões de banco separadas por
  # thread, o que exige desativar fixtures transacionais nesta classe — os
  # dados são criados e limpos manualmente (apenas os registros criados por
  # este teste, sem tocar nos dados dos fixtures compartilhados).
  class ProcessWebhookConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    test "the same event_id delivered twice at once applies the effect only once" do
      order, payment = build_order_with_payment
      event_id = SecureRandom.hex(10)

      results = []
      results_mutex = Mutex.new
      ready = Queue.new
      go = Queue.new

      threads = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            go.pop

            result = ProcessWebhook.new(event_id: event_id, external_id: payment.external_id, status: "approved").call
            results_mutex.synchronize { results << result }
          end
        end
      end

      2.times { ready.pop }
      2.times { go << true }
      threads.each(&:join)

      assert_equal 1, PaymentEvent.where(gateway_event_id: event_id).count
      assert payment.reload.paid?
      assert order.reload.confirmed?
    ensure
      cleanup(order, payment)
    end

    private

    def build_order_with_payment
      customer = Customer.create!(name: "Cliente", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!(seller: sellers(:approved), name: "P", sku: "SKU-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 5, currency: "BRL", status: "active")
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)
      order = Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
      payment = Authorize.new(order: order).call
      [ order, payment ]
    end

    # Remove só o que este teste criou, na ordem correta de dependência,
    # sem afetar os dados dos fixtures (transações desativadas nesta classe).
    def cleanup(order, payment)
      return if order.nil?

      product = order.order_items.first.product
      customer = order.customer

      PaymentEvent.where(payment_id: payment.id).delete_all if payment
      payment&.destroy
      OrderItem.where(order: order).delete_all
      order.seller_order&.destroy
      order.destroy
      customer.addresses.delete_all
      customer.destroy
      product.destroy
    end
  end
end
