require "test_helper"

module Checkout
  # Mesma abordagem de test/services/checkout/create_order_concurrency_test.rb:
  # dois checkouts concorrentes usando um cupom com uma única vaga de uso
  # restante não podem ambos ser bem-sucedidos.
  class CreateOrderCouponConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    test "only one of two simultaneous checkouts succeeds for the last coupon use" do
      coupon = Coupon.create!(code: "CONC-#{SecureRandom.hex(4)}", discount_type: "percentage", percentage: 10, max_uses: 1, uses_count: 0)
      attempts = [ build_attempt(coupon), build_attempt(coupon) ]

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
      assert_equal 1, coupon.reload.uses_count
    ensure
      cleanup(coupon, attempts)
    end

    private

    def build_attempt(coupon)
      customer = Customer.create!(name: "Cliente #{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!(seller: sellers(:approved), name: "Produto #{SecureRandom.hex(4)}", sku: "SKU-#{SecureRandom.hex(4)}", price_cents: 10_000, stock_quantity: 5, currency: "BRL", status: "active")
      cart = Cart.create!(session_token: SecureRandom.hex(10), coupon: coupon)
      cart.cart_items.create!(product: product, quantity: 1)
      [ cart, customer, address, product ]
    end

    def cleanup(coupon, attempts)
      return if coupon.nil?

      attempts ||= []

      customer_ids = attempts.to_a.filter_map { |attempt| attempt[1]&.id }
      orders = Order.where(customer_id: customer_ids)
      OrderItem.where(order: orders).delete_all
      orders.delete_all

      attempts.each do |cart, customer, _address, product|
        cart&.cart_items&.destroy_all
        cart&.destroy
        customer&.destroy
        product&.destroy
      end

      coupon.destroy
    end
  end
end
