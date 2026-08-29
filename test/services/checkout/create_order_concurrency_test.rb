require "test_helper"

module Checkout
  # Testes de concorrência real precisam de conexões de banco separadas por
  # thread, o que exige desativar fixtures transacionais nesta classe — os
  # dados são criados e limpos manualmente (apenas os registros criados por
  # este teste, sem tocar nos dados dos fixtures compartilhados).
  class CreateOrderConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    test "only one of two simultaneous checkouts succeeds for the last unit" do
      product = Product.create!(
        name: "Peça única", sku: "CONC-#{SecureRandom.hex(4)}",
        price_cents: 1000, stock_quantity: 1, currency: "BRL", status: "active"
      )

      attempts = [ build_attempt(product), build_attempt(product) ]

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
      assert_equal 0, product.reload.stock_quantity
      assert_equal 1, Order.where(customer_id: attempts.map { |_, customer, _| customer.id }).count
    ensure
      cleanup(product, attempts)
    end

    private

    def build_attempt(product)
      customer = Customer.create!(name: "Cliente #{SecureRandom.hex(4)}", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)
      [ cart, customer, address ]
    end

    # Remove só o que este teste criou, na ordem correta de dependência,
    # sem afetar os dados dos fixtures (transações desativadas nesta classe).
    def cleanup(product, attempts)
      return if product.nil?

      customer_ids = attempts.to_a.filter_map { |_, customer, _| customer&.id }
      orders = Order.where(customer_id: customer_ids)
      OrderItem.where(order: orders).delete_all
      orders.delete_all

      attempts.each do |cart, customer, _address|
        cart&.destroy
        customer&.destroy
      end

      product.destroy
    end
  end
end
