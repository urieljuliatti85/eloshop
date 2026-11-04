module Shipping
  # Fonte única das opções de frete de um carrinho.
  #
  # Cota no provedor que o vendedor conectou (ADR 005, Etapa 1; ver
  # `Shipping::Providers`) e cai no frete do ateliê ou na tabela interna
  # quando não conectou, quando o provedor falha ou quando ele não devolve
  # nenhuma opção — o ADR é explícito: "uma venda com frete estimado é melhor
  # que uma venda perdida", e a tabela não deve ser deletada.
  class Calculator
    class Unavailable < StandardError; end

    BASE_CENTS = 1500
    PER_KILOGRAM_CENTS = 500
    MAX_WEIGHT_GRAMS = 30_000

    # Origem, destino e peso se repetem muito entre uma mudança de endereço e
    # outra no checkout. Sem cache, cada uma vira chamada externa — e o rate
    # limit dos provedores não é documentado (ADR 005).
    CACHE_TTL = 30.minutes

    # Disjuntor: depois de uma falha, o ateliê fica este tempo sem cotar e
    # vai direto ao frete dele. Sem isso, um provedor lento (que estoura o
    # timeout em vez de recusar) custaria segundos por endereço do checkout,
    # a cada recarga, e prenderia as poucas threads do Puma — a loja inteira
    # pararia, não só o checkout. É por ateliê porque 401 (token revogado) e
    # CEP de origem inválido são falhas dele, não do provedor.
    PROVIDER_COOLDOWN = 1.minute

    # Rótulo da opção do vendedor no checkout: deixa claro ao cliente que o
    # valor vem de quem envia, não de uma cotação da transportadora.
    SELLER_DEFINED_SERVICE = "Frete definido pelo ateliê"

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
    #
    # Frete grátis é uma promessa do vendedor ao cliente, não uma estimativa
    # de custo — por isso vence sempre, mesmo com cotação real disponível.
    #
    # Entre a cotação do provedor e o frete que o ateliê definiu no produto,
    # quem escolhe é o ateliê (`Seller#provider_quotes_preferred`, falso por
    # padrão): os termos comerciais dizem que o frete é definido pelo
    # vendedor. Sem frete definido no produto, a cotação vem antes da tabela
    # interna, que é só o último recurso.
    def quotes
      validate!

      delivery_quotes = if any_product_free_shipping?
        [ product_shipping_quote ]
      else
        seller_defined = product_shipping_quote
        if seller_defined && !seller.provider_quotes_preferred?
          [ seller_defined ]
        else
          remote_quotes.presence || [ seller_defined || fallback_quote ]
        end
      end

      all_products_allow_pickup? ? delivery_quotes + [ local_pickup_quote ] : delivery_quotes
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
      return [] unless provider
      return [] unless seller.origin_zip_code.present?
      return [] if Rails.cache.exist?(cooldown_key)

      cheapest_and_fastest(cached_remote_quotes)
    rescue Providers::Unavailable => e
      # A cotação real é uma otimização do valor, não um requisito do
      # checkout: registrar e seguir com a tabela vale mais que derrubar a
      # compra.
      Rails.cache.write(cooldown_key, true, expires_in: PROVIDER_COOLDOWN)
      Rails.event.notify("shipping.provider_unavailable", provider: provider_name, reason: e.message)
      []
    end

    def cooldown_key
      [ "shipping", provider_name, "cooldown", seller.id ].join("/")
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

    # Cada produto define seu próprio custo. O valor é por unidade; no mesmo
    # pedido, os custos são somados e o maior prazo é o prometido ao cliente.
    # Produtos legados sem configuração continuam usando a parcela estimada
    # da tabela interna. Se nenhum produto configurou nada, `fallback_quote`
    # preserva exatamente o cálculo anterior para o carrinho inteiro.
    #
    # `free_shipping` também dispara este caminho por conta própria: um
    # produto marcado como frete grátis, mesmo sem `fixed_shipping`
    # configurado, precisa zerar sua parcela em vez de cair no fallback (que
    # ignoraria o toggle e cobraria a tabela interna). O custo é absorvido
    # pelo vendedor — não entra na base da comissão da plataforma, que já
    # exclui frete (CLAUDE.md §34).
    def product_shipping_quote
      return unless cart_items.any? { |item| item.product.fixed_shipping_configured? || item.product.free_shipping? }

      Quote.new(
        carrier: "Ateliê",
        service: SELLER_DEFINED_SERVICE,
        shipping_cents: cart_items.sum { |item| shipping_cents_for(item) },
        estimated_days: cart_items.map { |item| estimated_days_for_item(item) }.max
      )
    end

    def shipping_cents_for(item)
      product = item.product
      return 0 if product.free_shipping?
      return seller_defined_band(product).first * item.quantity if product.fixed_shipping_configured?

      BASE_CENTS + (((product.weight_grams.to_i * item.quantity) / 1000.0).ceil * PER_KILOGRAM_CENTS)
    end

    def estimated_days_for_item(item)
      product = item.product
      return seller_defined_band(product).last if product.fixed_shipping_configured?

      estimated_days_for(destination_zip_code)
    end

    # Faixa do frete definido pelo vendedor, como [centavos, dias]. A faixa
    # para outros estados é opcional: sem ela, o valor principal vale para
    # todo o Brasil. Sem o estado de origem do ateliê não há como saber se o
    # destino é interestadual, então vale o pior caso de cada lado: o maior
    # valor (quem paga a etiqueta é o vendedor) e o maior prazo (o pedido não
    # pode prometer menos do que o envio pode levar). Preço e prazo são
    # escolhidos à parte: uma faixa mais barata pode ser a mais lenta.
    def seller_defined_band(product)
      base = [ product.fixed_shipping_cents, product.fixed_shipping_estimated_days ]
      return base unless product.fixed_shipping_interstate_configured?

      interstate = [ product.fixed_shipping_interstate_cents, product.fixed_shipping_interstate_estimated_days ]
      case destination_interstate?
      when true then interstate
      when false then base
      else base.zip(interstate).map(&:max)
      end
    end

    # true/false quando os dois estados são conhecidos; nil quando falta um.
    def destination_interstate?
      origin = seller&.origin_state.to_s.strip.upcase
      destination = @address.try(:state).to_s.strip.upcase
      return nil if origin.blank? || destination.blank?

      origin != destination
    end

    def any_product_free_shipping?
      cart_items.any? { |item| item.product.free_shipping? }
    end

    def all_products_allow_pickup?
      cart_items.present? && cart_items.all? { |item| item.product.local_pickup_enabled? }
    end

    def local_pickup_quote
      Quote.new(
        carrier: "Ateliê",
        service: Shipping::Quote::LOCAL_PICKUP_SERVICE,
        shipping_cents: 0,
        estimated_days: 0
      )
    end

    # Quem decide se há cotação externa é a conexão do ateliê (e a chave do
    # ambiente), nunca a injeção: o provedor injetado nos testes só substitui
    # o real quando o ateliê tem um conectado.
    def provider
      return @resolved_provider if defined?(@resolved_provider)

      connected = Providers.for(seller)
      @resolved_provider = connected && (@provider || connected)
    end

    def provider_name
      provider.class.name.to_s.demodulize.underscore
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

    # Tudo o que muda o preço entra na chave: a versão do produto (peso,
    # medidas e preço do seguro) e, do provedor, a conta e o ambiente — trocar
    # de conta ou editar a peça não pode reaproveitar a cotação antiga.
    def cache_key
      digest = cart_items.map { |item| "#{item.product_id}:#{item.quantity}:#{item.product.cache_version}" }.sort.join(",")
      [ "shipping", provider_name, provider.try(:cache_scope), seller.id, seller.origin_zip_code, destination_zip_code,
        Digest::SHA256.hexdigest(digest) ].join("/")
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
