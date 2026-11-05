module ShippingLabels
  # O ateliê escolheu o serviço e o pacote no painel. Recota no servidor (o
  # preço nunca vem do navegador), confere as pré-condições com o envio
  # travado e grava a etiqueta em `draft`; a compra segue em job
  # (PurchaseShippingLabelJob), fora da requisição.
  class Request
    def initialize(shipment:, service_code:, height_cm:, width_cm:, length_cm:, weight_grams:, client: nil)
      @shipment = shipment
      @seller = shipment.seller_order.seller
      @service_code = Integer(service_code, exception: false)
      @package = { height_cm:, width_cm:, length_cm:, weight_grams: }.transform_values { |value| Integer(value, exception: false) }
      @client = client || ShippingLabels.client_for(@seller, interactive: true)
    end

    def call
      if (message = Guard.account_blocker(@seller, @shipment.order))
        raise Refused, message
      end
      raise Refused, "Informe altura, largura, comprimento e peso do pacote." unless @package.values.all? { |value| value.to_i.positive? }

      option = quoted_option
      label = nil
      @shipment.seller_order.with_lock do
        if (message = Guard.blocker(@shipment))
          raise Refused, message
        end
        raise Refused, "Já existe uma etiqueta para este pedido." if @shipment.shipping_labels.active.exists?

        label = @shipment.shipping_labels.create!(
          service_code: option.service_code,
          service_name: option.service_name,
          quoted_price_cents: option.price_cents,
          height_cm: option.height_cm,
          width_cm: option.width_cm,
          length_cm: option.length_cm,
          weight_grams: option.weight_grams,
          sandbox: @seller.superfrete_sandbox?,
          superfrete_account_id: @seller.superfrete_account_id
        )
      end

      PurchaseShippingLabelJob.perform_later(label)
      label
    rescue ActiveRecord::RecordNotUnique
      raise Refused, "Já existe uma etiqueta para este pedido."
    end

    private

    def quoted_option
      address = @shipment.order.shipping_address_snapshot
      options = @client.quote(
        origin_zip_code: @seller.origin_zip_code.to_s.gsub(/\D/, ""),
        destination_zip_code: address["zip_code"].to_s.gsub(/\D/, ""),
        **@package
      )
      options.find { |option| option.service_code == @service_code } ||
        raise(Refused, "Esse serviço não está disponível para este pacote e destino. Escolha outro.")
    rescue Client::Error => e
      raise Refused, "Não foi possível cotar a etiqueta: #{e.message}"
    end
  end
end
