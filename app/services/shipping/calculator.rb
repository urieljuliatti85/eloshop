module Shipping
  # Fonte única das opções de frete de um carrinho.
  #
  # Cota no Melhor Envio quando o vendedor conectou a conta (ADR 005, Etapa
  # 1) e cai na tabela interna quando não conectou, quando o provedor falha
  # ou quando ele não devolve nenhuma opção — o ADR é explícito: "uma venda
  # com frete estimado é melhor que uma venda perdida", e a tabela não deve
  # ser deletada.
  class Calculator
    class Unavailable < StandardError; end

    BASE_CENTS = 1500
    PER_KILOGRAM_CENTS = 500
    MAX_WEIGHT_GRAMS = 30_000

    # Origem, destino e peso se repetem muito entre uma mudança de endereço e
    # outra no checkout. Sem cache, cada uma vira chamada externa — e o rate
    # limit do Melhor Envio não é documentado (ADR 005).
    CACHE_TTL = 30.minutes

    # A tabela interna não tem opção "mais rápida": é uma linha só.
    Result = Quote

    def initialize(cart:, address:, provider: nil)
      @cart = cart
      @address = address
      @provider = provider
    end

    # Todas as opções ofertadas, já reduzidas ao que o cliente escolhe: a
    # mais barata e a mais rápida (ADR 005 — mostrar todas sobrecarrega). São
    # a mesma opção quando o serviço mais barato também é o mais rápido.
    def quotes
      validate!

      remote_quotes.presence || [ fallback_quote ]
    end

    # A opção escolhida pelo cliente, revalidada contra a cotação do
    # servidor. Sem `id`, devolve a mais barata — é o default do checkout e o
    # comportamento anterior a esta fase, quando havia uma opção só.
    def call(quote_id: nil)
      available = quotes
      return available.first if quote_id.blank?

      available.find { |quote| quote.id == quote_id } ||
        raise(Unavailable, "A opção de frete escolhida não está mais disponível. Escolha outra.")
    end

    private

    def validate!
      raise Unavailable, "Não foi possível calcular o frete para este CEP." unless destination_zip_code.match?(/\A\d{8}\z/)
      raise Unavailable, "O peso do pedido excede o limite de envio." if total_weight_grams > MAX_WEIGHT_GRAMS
    end

    def remote_quotes
      return [] unless seller&.melhor_envio_connected?
      return [] unless seller.origin_zip_code.present?

      cheapest_and_fastest(cached_remote_quotes)
    rescue Providers::MelhorEnvio::Unavailable => e
      # A cotação real é uma otimização do valor, não um requisito do
      # checkout: registrar e seguir com a tabela vale mais que derrubar a
      # compra.
      Rails.event.notify("shipping.provider_unavailable", provider: "melhor_envio", reason: e.message)
      []
    end

    def cached_remote_quotes
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        provider.quotes(
          origin_zip_code: seller.origin_zip_code,
          destination_zip_code: destination_zip_code,
          items: provider_items
        )
      end
    end

    def cheapest_and_fastest(available)
      return [] if available.blank?

      cheapest = available.min_by(&:shipping_cents)
      fastest = available.min_by { |quote| [ quote.estimated_days, quote.shipping_cents ] }

      [ cheapest, fastest ].uniq
    end

    def fallback_quote
      Quote.new(
        carrier: "EloShop",
        service: "Entrega padrão",
        shipping_cents: BASE_CENTS + ((total_weight_grams / 1000.0).ceil * PER_KILOGRAM_CENTS),
        estimated_days: estimated_days_for(destination_zip_code)
      )
    end

    def provider
      @provider ||= Providers::MelhorEnvio.new(seller: seller)
    end

    def provider_items
      cart_items.map do |item|
        {
          id: item.product_id,
          width_cm: item.product.width_cm,
          height_cm: item.product.height_cm,
          length_cm: item.product.length_cm,
          weight_grams: item.product.weight_grams,
          price_cents: item.product.price_cents,
          quantity: item.quantity
        }
      end
    end

    def cache_key
      digest = cart_items.map { |item| "#{item.product_id}:#{item.quantity}" }.sort.join(",")
      [ "shipping/melhor_envio", seller.id, seller.origin_zip_code, destination_zip_code, Digest::SHA256.hexdigest(digest) ].join("/")
    end

    def cart_items
      @cart_items ||= @cart.cart_items.includes(:product).to_a
    end

    def seller
      @seller ||= cart_items.first&.product&.seller
    end

    def destination_zip_code
      @destination_zip_code ||= @address.zip_code.to_s.delete("-").strip
    end

    def total_weight_grams
      @total_weight_grams ||= cart_items.sum { |item| item.product.weight_grams.to_i * item.quantity }
    end

    def estimated_days_for(zip_code)
      zip_code.start_with?("0", "1", "2", "3") ? 5 : 8
    end
  end
end
