module ShippingLabels
  # Compra a etiqueta na SuperFrete, um passo por estado (ver ShippingLabel):
  #
  # * `draft` → cria o pedido lá e grava o id (`cart_created`). Uma falha
  #   antes de gravar deixa, no máximo, um pedido pendente sem cobrança.
  # * `cart_created` → confere de novo, com o envio travado, se ainda pode
  #   comprar (desistência ou reembolso podem ter chegado enquanto o job
  #   esperava), marca `purchasing` e paga.
  # * `purchasing` → o pagamento foi enviado e a resposta se perdeu: só a
  #   consulta do pedido decide. **O pagamento nunca é reenviado
  #   automaticamente** depois de um resultado incerto: pendente lá continua
  #   `purchasing` e o job tenta conferir de novo; o ateliê pode cancelar.
  #
  # Chamadas externas ficam fora de transação (regra do ADR 008).
  class Purchase
    # Algo incerto que vale conferir de novo mais tarde (o job repete).
    class Retry < StandardError; end

    CANCEL_REASON = "Compra interrompida pela EloShop".freeze

    def initialize(label, client: nil, order_url: nil)
      @label = label
      @seller = label.seller_order.seller
      @client = client || ShippingLabels.client_for(@seller)
      @order_url = order_url || default_order_url
    end

    def call
      create_cart if @label.draft?
      pay if @label.cart_created?
      reconcile if @label.purchasing?
      @label
    end

    private

    def create_cart
      unless same_account?
        return @label.advance!(from: :draft, to: :failed, failure_message: "A conta SuperFrete do ateliê mudou depois do pedido da etiqueta. Peça de novo.")
      end

      cart = @client.create_cart(Payload.new(@label, order_url: @order_url).to_h)
      return if @label.advance!(from: :draft, to: :cart_created, provider_order_id: cart.fetch(:id), price_cents: cart[:price_cents])

      # Outro job (ou "Conferir de novo") chegou antes e já gravou o pedido
      # dele: o que este criou ficaria pendente e órfão na SuperFrete.
      cancel_quietly(cart.fetch(:id))
    rescue Client::Rejected => e
      @label.advance!(from: :draft, to: :failed, failure_message: e.message)
    rescue Client::Ambiguous => e
      raise Retry, e.message
    end

    def pay
      blocked = nil
      @label.seller_order.with_lock do
        blocked = Guard.blocker(@label.shipment) || price_changed_message
        @label.advance!(from: :cart_created, to: :purchasing) unless blocked
      end

      return abandon_cart(blocked) if blocked
      return unless @label.purchasing?

      purchase = @client.checkout(@label.provider_order_id)
      mark_purchased(tracking: purchase[:tracking], price_cents: purchase[:price_cents])
    rescue Client::Rejected => e
      # Sem saldo, por exemplo: nada foi cobrado. Antes de dar como falha,
      # confere — uma recusa de pedido já pago não pode virar "falhou".
      info = safe_order_info
      if info&.paid?
        mark_purchased(tracking: info.tracking, price_cents: info.price_cents)
      else
        @label.advance!(from: :purchasing, to: :failed, failure_message: e.message)
        cancel_quietly
      end
    rescue Client::Ambiguous
      reconcile
    end

    def reconcile
      info = @client.order_info(@label.provider_order_id)

      if info.paid?
        mark_purchased(tracking: info.tracking, price_cents: info.price_cents)
      elsif info.cancelled?
        @label.advance!(from: :purchasing, to: :failed, failure_message: "O pedido foi cancelado na SuperFrete antes do pagamento.")
      else
        raise Retry, "pagamento ainda não confirmado pela SuperFrete"
      end
    rescue Client::Error => e
      raise Retry, e.message
    end

    # O ateliê aprovou o preço cotado. Se o pedido criado na SuperFrete sair
    # mais caro, não paga: a diferença sairia da carteira dele sem ele ver.
    def price_changed_message
      return if @label.price_cents.nil? || @label.price_cents <= @label.quoted_price_cents

      "O preço da etiqueta mudou de #{money(@label.quoted_price_cents)} para #{money(@label.price_cents)}. Nada foi cobrado: cote de novo."
    end

    def money(cents)
      ActiveSupport::NumberHelper.number_to_currency(cents / 100r, unit: "R$", separator: ",", delimiter: ".", format: "%u %n")
    end

    def mark_purchased(tracking:, price_cents:)
      @label.advance!(from: :purchasing, to: :purchased, tracking_code: tracking, price_cents: price_cents || @label.price_cents,
        purchased_at: Time.current, failure_message: nil)
      Rails.event.notify("shipping.label_purchased", shipping_label_id: @label.id, seller_id: @seller.id)
    end

    def abandon_cart(message)
      @label.advance!(from: :cart_created, to: :cancelled, cancelled_at: Time.current, failure_message: message)
      cancel_quietly
    end

    # O pedido pendente na SuperFrete não cobra nada; cancelar é só arrumação.
    def cancel_quietly(provider_order_id = @label.provider_order_id)
      @client.cancel(provider_order_id, reason: CANCEL_REASON)
    rescue Client::Error
      nil
    end

    def safe_order_info
      @client.order_info(@label.provider_order_id)
    rescue Client::Error
      nil
    end

    # Reconectar outra conta entre o pedido e a compra pagaria com a carteira
    # errada.
    def same_account?
      @seller.superfrete_account_id == @label.superfrete_account_id && @seller.superfrete_sandbox? == @label.sandbox?
    end

    def default_order_url
      Rails.application.routes.url_helpers.seller_order_url(@label.seller_order.order, **Rails.application.config.action_mailer.default_url_options.to_h)
    end
  end
end
