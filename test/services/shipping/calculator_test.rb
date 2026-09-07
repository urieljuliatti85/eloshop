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

    test "rejects an order above the weight limit" do
      product = products(:one)
      product.update!(weight_grams: Calculator::MAX_WEIGHT_GRAMS + 1)
      cart = cart_with(product)

      assert_raises(Calculator::Unavailable) { Calculator.new(cart: cart, address: addresses(:one)).call }
    end

    test "offers the cheapest and the fastest option from the provider" do
      cart = connected_seller_cart
      provider = stub_provider([
        Quote.new(carrier: "Correios", service: "PAC", shipping_cents: 2000, estimated_days: 8),
        Quote.new(carrier: "Correios", service: "SEDEX", shipping_cents: 4500, estimated_days: 2),
        Quote.new(carrier: "Jadlog", service: ".Package", shipping_cents: 3000, estimated_days: 5)
      ])

      quotes = Calculator.new(cart: cart, address: addresses(:one), provider: provider).quotes

      assert_equal 2, quotes.size
      assert_equal [ "PAC", "SEDEX" ], quotes.map(&:service).sort
      assert_equal 2000, quotes.first.shipping_cents
    end

    # Quando o serviço mais barato também é o mais rápido, não faz sentido
    # oferecer a mesma opção duas vezes.
    test "collapses a single option when it is both cheapest and fastest" do
      cart = connected_seller_cart
      provider = stub_provider([
        Quote.new(carrier: "Correios", service: "SEDEX", shipping_cents: 2000, estimated_days: 2),
        Quote.new(carrier: "Correios", service: "PAC", shipping_cents: 4000, estimated_days: 9)
      ])

      quotes = Calculator.new(cart: cart, address: addresses(:one), provider: provider).quotes

      assert_equal 1, quotes.size
      assert_equal "SEDEX", quotes.sole.service
    end

    # ADR 005: uma venda com frete estimado é melhor que uma venda perdida.
    test "falls back to the internal table when the provider fails" do
      cart = connected_seller_cart
      provider = Object.new
      provider.define_singleton_method(:quotes) { |**| raise Providers::MelhorEnvio::Unavailable, "timeout" }

      quotes = Calculator.new(cart: cart, address: addresses(:one), provider: provider).quotes

      assert_equal "EloShop", quotes.sole.carrier
    end

    test "falls back to the internal table when the provider returns nothing" do
      cart = connected_seller_cart

      quotes = Calculator.new(cart: cart, address: addresses(:one), provider: stub_provider([])).quotes

      assert_equal "EloShop", quotes.sole.carrier
    end

    test "does not call the provider when the seller has not connected" do
      cart = cart_with(products(:one))
      provider = Object.new
      provider.define_singleton_method(:quotes) { |**| raise "não deveria cotar" }

      quotes = Calculator.new(cart: cart, address: addresses(:one), provider: provider).quotes

      assert_equal "EloShop", quotes.sole.carrier
    end

    # Sem CEP de origem nenhuma cotação real funciona, qualquer que seja a
    # transportadora — e o endereço do ateliê ainda é opcional.
    test "does not call the provider when the seller has no origin postal code" do
      cart = connected_seller_cart(origin_zip_code: nil)
      provider = Object.new
      provider.define_singleton_method(:quotes) { |**| raise "não deveria cotar" }

      quotes = Calculator.new(cart: cart, address: addresses(:one), provider: provider).quotes

      assert_equal "EloShop", quotes.sole.carrier
    end

    test "call selects the chosen option by id" do
      cart = connected_seller_cart
      provider = stub_provider([
        Quote.new(carrier: "Correios", service: "PAC", shipping_cents: 2000, estimated_days: 8),
        Quote.new(carrier: "Correios", service: "SEDEX", shipping_cents: 4500, estimated_days: 2)
      ])
      calculator = Calculator.new(cart: cart, address: addresses(:one), provider: provider)
      sedex = calculator.quotes.find { |quote| quote.service == "SEDEX" }

      assert_equal 4500, calculator.call(quote_id: sedex.id).shipping_cents
    end

    # O cliente manda o identificador da opção, nunca o preço: uma escolha que
    # sumiu entre a exibição e a confirmação precisa falhar, não virar outra.
    test "call refuses an option that is no longer offered" do
      cart = connected_seller_cart
      provider = stub_provider([ Quote.new(carrier: "Correios", service: "PAC", shipping_cents: 2000, estimated_days: 8) ])
      calculator = Calculator.new(cart: cart, address: addresses(:one), provider: provider)

      assert_raises(Calculator::Unavailable) { calculator.call(quote_id: "correios-sedex") }
    end

    test "call without an id keeps the previous behaviour and returns the cheapest" do
      cart = connected_seller_cart
      provider = stub_provider([
        Quote.new(carrier: "Correios", service: "SEDEX", shipping_cents: 4500, estimated_days: 2),
        Quote.new(carrier: "Correios", service: "PAC", shipping_cents: 2000, estimated_days: 8)
      ])

      result = Calculator.new(cart: cart, address: addresses(:one), provider: provider).call

      assert_equal 2000, result.shipping_cents
    end

    private

    def stub_provider(quotes)
      Object.new.tap do |provider|
        provider.define_singleton_method(:quotes) { |**| quotes }
      end
    end

    def cart_with(product)
      Cart.create!(session_token: SecureRandom.hex(10)).tap do |cart|
        cart.cart_items.create!(product: product, quantity: 1)
      end
    end

    # O endereço de origem é tudo-ou-nada (Seller#origin_address_started?):
    # meio endereço não despacha nada.
    def connected_seller_cart(origin_zip_code: "01001000")
      seller = sellers(:approved)
      seller.connect_melhor_envio!(
        Marketplace::MelhorEnvioOauth::Credentials.new(
          access_token: "token", refresh_token: "refresh", expires_at: 30.days.from_now
        )
      )
      origin = if origin_zip_code.present?
        { origin_zip_code: origin_zip_code, origin_street: "Rua do Ateliê", origin_number: "10",
          origin_neighborhood: "Centro", origin_city: "São Paulo", origin_state: "SP" }
      else
        Seller::ORIGIN_ADDRESS_FIELDS.index_with { nil }
      end
      seller.update!(origin)

      cart_with(products(:one))
    end
  end
end
