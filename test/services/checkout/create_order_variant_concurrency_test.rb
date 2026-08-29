require "test_helper"

module Checkout
  # Mesma técnica de test/services/checkout/create_order_concurrency_test.rb,
  # mas para a última unidade de uma ProductVariant (Fase 9) em vez do
  # Product — o estoque da variante é uma fonte de verdade separada e
  # precisa do mesmo tipo de proteção contra corrida.
  class CreateOrderVariantConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    test "only one of two simultaneous checkouts succeeds for the last unit of a variant" do
      product = Product.create!(
        name: "Camiseta de teste", sku: "CONC-VAR-#{SecureRandom.hex(4)}",
        price_cents: 1000, stock_quantity: 0, currency: "BRL", status: "active"
      )
      variant = product.product_variants.create!(sku: "CONC-VAR-P-#{SecureRandom.hex(4)}", price_cents: 1500, stock_quantity: 1, size: "P")

      attempts = [ build_attempt(product, variant), build_attempt(product, variant) ]

      results = []
      results_mutex = Mutex.new
      ready = Queue.new
      go = Queue.new

      threads = attempts.map do |cart, customer, address|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            go.pop

            begin
              order = CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
              results_mutex.synchronize { results << { success: true, order: order } }
            rescue CreateOrder::Failed => e
              results_mutex.synchronize { results << { success: false, error: e.message } }
            end
          end
        end
      end

      attempts.size.times { ready.pop }
      attempts.size.times { go << true }
      threads.each(&:join)

      assert_equal 1, results.count { |r| r[:success] }
      assert_equal 1, results.count { |r| !r[:success] }
      assert_equal 0, variant.reload.stock_quantity
      assert_equal 1, Order.where(customer_id: attempts.map { |_, customer, _| customer.id }).count
    ensure
      cleanup(product, variant, attempts)
    end

    private

    def build_attempt(product, variant)
      customer = Customer.create!(name: "Cliente #{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, product_variant: variant, quantity: 1)
      [ cart, customer, address ]
    end

    def cleanup(product, variant, attempts)
      return if product.nil?

      customer_ids = attempts.to_a.filter_map { |_, customer, _| customer&.id }
      orders = Order.where(customer_id: customer_ids)
      OrderItem.where(order: orders).delete_all
      orders.delete_all

      attempts.each do |cart, customer, _address|
        cart&.destroy
        customer&.destroy
      end

      variant&.destroy
      product.destroy
    end
  end
end
