module Checkout
  # Transforma um carrinho validado em um pedido. Ver docs/checkout.md e
  # docs/inventory.md para os princípios (nunca confiar no cliente, snapshot,
  # idempotência, concorrência) que este serviço implementa.
  class CreateOrder
    class Failed < StandardError; end

    # Frete fixo do MVP — cálculo real (Correios) é pós-MVP, ver Fase 12 do
    # ROADMAP.md e docs/shipping.md.
    SHIPPING_CENTS = 1500

    def initialize(cart:, customer:, address:, idempotency_key:)
      @cart = cart
      @customer = customer
      @address = address
      @idempotency_key = idempotency_key
    end

    def call
      existing_order = Order.find_by(idempotency_key: @idempotency_key)
      return existing_order if existing_order

      create_order!
    rescue ActiveRecord::RecordNotUnique
      Order.find_by!(idempotency_key: @idempotency_key)
    end

    private

    def create_order!
      Order.transaction do
        cart_items = lock_and_revalidate_cart_items!
        subtotal = subtotal_cents(cart_items)

        order = Order.create!(
          customer: @customer,
          status: "pending",
          subtotal_cents: subtotal,
          shipping_cents: SHIPPING_CENTS,
          total_cents: subtotal + SHIPPING_CENTS,
          shipping_address_snapshot: address_snapshot,
          idempotency_key: @idempotency_key
        )

        cart_items.each { |cart_item| create_order_item_and_debit_stock!(order, cart_item) }

        @cart.cart_items.destroy_all

        order
      end
    end

    # Bloqueia cada produto envolvido (SELECT ... FOR UPDATE) antes de
    # revalidar disponibilidade e quantidade, para que dois checkouts
    # simultâneos na última unidade não vendam a mesma peça duas vezes. Um
    # item com variante (Fase 9) também bloqueia a ProductVariant — o estoque
    # dela é a fonte de verdade, não o do produto. Tudo é bloqueado em ordem
    # estável (product_id, depois product_variant_id) para evitar deadlock
    # quando um carrinho tem mais de um item.
    def lock_and_revalidate_cart_items!
      cart_items = @cart.cart_items.includes(:product, :product_variant)
                        .order(:product_id, :product_variant_id).to_a
      raise Failed, "Carrinho vazio." if cart_items.empty?

      cart_items.each do |cart_item|
        product = cart_item.product
        product.lock!

        if cart_item.product_variant
          raise Failed, "#{product.name} não está mais disponível." unless product.active?

          lock_and_validate_variant!(cart_item)
        else
          raise Failed, "#{product.name} não está mais disponível." unless product.available_for_purchase?

          if !product.availability_type_made_to_order? && cart_item.quantity > product.stock_quantity
            raise Failed, "Estoque insuficiente para #{product.name}."
          end
        end
      end

      cart_items
    end

    def lock_and_validate_variant!(cart_item)
      variant = cart_item.product_variant
      variant.lock!

      label = "#{cart_item.product.name} (#{variant.to_label})"

      raise Failed, "#{label} não está mais disponível." unless variant.available_for_purchase?
      raise Failed, "Estoque insuficiente para #{label}." if cart_item.quantity > variant.stock_quantity
    end

    def create_order_item_and_debit_stock!(order, cart_item)
      product = cart_item.product
      variant = cart_item.product_variant

      order.order_items.create!(
        product: product,
        product_variant: variant,
        product_name: product.name,
        sku: variant&.sku || product.sku,
        variant_sku: variant&.sku,
        unit_price_cents: cart_item.unit_price_cents,
        quantity: cart_item.quantity,
        production_time_snapshot: product.production_time_range,
        size_snapshot: variant&.size,
        color_snapshot: variant&.color,
        material_snapshot: variant&.material,
        personalizations: cart_item.personalization_entries.map { |entry| entry.transform_keys(&:to_s) }
      )

      if variant
        variant.update!(stock_quantity: variant.stock_quantity - cart_item.quantity)
        return
      end

      # Produto sob encomenda não tem estoque físico — ver docs/inventory.md.
      return if product.availability_type_made_to_order?

      product.update!(stock_quantity: product.stock_quantity - cart_item.quantity)
    end

    def subtotal_cents(cart_items)
      cart_items.sum { |cart_item| cart_item.unit_price_cents * cart_item.quantity }
    end

    def address_snapshot
      @address.attributes.slice("street", "number", "complement", "neighborhood", "city", "state", "zip_code")
    end
  end
end
