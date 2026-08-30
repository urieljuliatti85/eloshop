require "test_helper"

module Shipping
  class CalculatorTest < ActiveSupport::TestCase
    test "calculates standard shipping from destination and weight" do
      product = products(:one)
      product.update!(weight_grams: 1200)
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 2)
      address = addresses(:one)

      result = Calculator.new(cart: cart, address: address).call

      assert_equal "EloShop", result.carrier
      assert_equal "Entrega padrão", result.service
      assert_equal 3000, result.shipping_cents
      assert_equal 5, result.estimated_days
    end

    test "rejects invalid destination postal code" do
      address = addresses(:one)
      address.update!(zip_code: "123")
      cart = Cart.create!(session_token: SecureRandom.hex(10))

      assert_raises(Calculator::Unavailable) { Calculator.new(cart: cart, address: address).call }
    end
  end
end
