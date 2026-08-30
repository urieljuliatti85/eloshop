module Shipping
  class Calculator
    class Unavailable < StandardError; end

    BASE_CENTS = 1500
    PER_KILOGRAM_CENTS = 500
    MAX_WEIGHT_GRAMS = 30_000

    Result = Data.define(:carrier, :service, :shipping_cents, :estimated_days)

    def initialize(cart:, address:)
      @cart = cart
      @address = address
    end

    def call
      zip_code = @address.zip_code.to_s.delete("-").strip
      raise Unavailable, "Não foi possível calcular o frete para este CEP." unless zip_code.match?(/\A\d{8}\z/)

      weight = total_weight_grams
      raise Unavailable, "O peso do pedido excede o limite de envio." if weight > MAX_WEIGHT_GRAMS

      Result.new(
        carrier: "EloShop",
        service: "Entrega padrão",
        shipping_cents: BASE_CENTS + ((weight / 1000.0).ceil * PER_KILOGRAM_CENTS),
        estimated_days: estimated_days_for(zip_code)
      )
    end

    private

    def total_weight_grams
      @cart.cart_items.sum do |item|
        item.product.weight_grams.to_i * item.quantity
      end
    end

    def estimated_days_for(zip_code)
      zip_code.start_with?("0", "1", "2", "3") ? 5 : 8
    end
  end
end
