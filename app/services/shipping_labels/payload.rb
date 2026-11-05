module ShippingLabels
  # O corpo do `POST /api/v0/cart`: remetente (o ateliê), destinatário (o que o
  # comprador informou no checkout), serviço, pacote e conteúdo. Formato
  # conferido no sandbox em 2026-11-05: `to.document` é obrigatório, e a
  # referência da EloShop vai em `options.tags` (no topo do corpo é ignorada).
  #
  # Declaração de conteúdo (`non_commercial: true`): o artesão sem CNPJ não
  # emite nota fiscal, e a nota é responsabilidade dele quando houver (ADR 004).
  class Payload
    def initialize(label, order_url:)
      @label = label
      @shipment = label.shipment
      @seller_order = @shipment.seller_order
      @order = @seller_order.order
      @seller = @seller_order.seller
      @order_url = order_url
    end

    def to_h
      {
        from: sender,
        to: recipient,
        service: @label.service_code,
        volumes: {
          height: @label.height_cm,
          width: @label.width_cm,
          length: @label.length_cm,
          weight: (@label.weight_grams / 1000.0).round(3)
        },
        products: products,
        options: {
          non_commercial: true,
          insurance_value: 0,
          receipt: false,
          own_hand: false,
          invoice: { number: "" },
          tags: [ { tag: "eloshop-shipment-#{@shipment.id}", url: @order_url } ]
        }
      }
    end

    private

    def sender
      {
        name: @seller.owner_full_name.presence || @seller.name,
        address: @seller.origin_street,
        number: @seller.origin_number,
        complement: @seller.origin_complement.to_s,
        district: @seller.origin_neighborhood,
        city: @seller.origin_city,
        state_abbr: @seller.origin_state,
        postal_code: digits(@seller.origin_zip_code)
      }
    end

    def recipient
      address = @order.shipping_address_snapshot
      {
        name: @order.recipient_display_name,
        document: @order.recipient_cpf,
        phone: @order.recipient_phone,
        email: nil,
        address: address["street"],
        number: address["number"],
        complement: address["complement"].to_s,
        district: address["neighborhood"],
        city: address["city"],
        state_abbr: address["state"],
        postal_code: digits(address["zip_code"])
      }
    end

    def products
      @seller_order.order_items.map do |item|
        { name: item.product_name, quantity: item.quantity.to_s, unitary_value: format("%.2f", item.unit_price_cents / 100.0) }
      end
    end

    def digits(value)
      value.to_s.gsub(/\D/, "")
    end
  end
end
