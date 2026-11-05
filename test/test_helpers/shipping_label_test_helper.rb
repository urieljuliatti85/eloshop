# Apoio dos testes de etiqueta (ShippingLabels): um pedido pago, pronto para
# etiqueta, e um cliente SuperFrete falso que registra as chamadas.
module ShippingLabelTestHelper
  # Responde com o que cada teste configurar; o padrão é o caminho feliz
  # observado no sandbox em 2026-11-05.
  class FakeClient
    attr_reader :calls
    attr_accessor :quote_result, :cart_result, :checkout_result, :info_result, :cancel_result

    def initialize
      @calls = []
      @quote_result = [ option(service_code: 1, service_name: "PAC", price_cents: 2351) ]
      @cart_result = { id: "sf-order-1", price_cents: 2351 }
      @checkout_result = { tracking: "AA123456789BR", price_cents: 2351 }
      @info_result = info(status: "released", tracking: "AA123456789BR")
      @cancel_result = true
    end

    def quote(**args) = respond(:quote, args, @quote_result)
    def create_cart(payload) = respond(:create_cart, payload, @cart_result)
    def checkout(id) = respond(:checkout, id, @checkout_result)
    def order_info(id) = respond(:order_info, id, @info_result)
    def cancel(id, reason:) = respond(:cancel, id, @cancel_result)

    def called?(name) = calls.any? { |call| call.first == name }
    def count(name) = calls.count { |call| call.first == name }

    def option(service_code:, service_name:, price_cents:, height_cm: 10, width_cm: 16, length_cm: 24, weight_grams: 500)
      ShippingLabels::Client::Option.new(service_code:, service_name:, carrier: "Correios", price_cents:, delivery_days: 3,
        height_cm:, width_cm:, length_cm:, weight_grams:)
    end

    def info(status:, tracking: nil, print_url: "https://sandbox.superfrete.com/etiqueta.pdf")
      ShippingLabels::Client::OrderInfo.new(id: "sf-order-1", status:, tracking:, price_cents: 2351, service_code: 1, print_url:)
    end

    private

    # Um resultado pode ser um valor, uma exceção (levantada) ou um lambda.
    def respond(name, args, result)
      @calls << [ name, args ]
      result = result.call if result.respond_to?(:call)
      raise result if result.is_a?(Exception)

      result
    end
  end

  # Ateliê com conta SuperFrete do mesmo e-mail do acesso ao painel, endereço
  # de origem completo, e um pedido pago com CPF de quem recebe.
  def prepare_label_scenario
    @seller = sellers(:approved)
    @seller.update!(origin_zip_code: "01001-000", origin_street: "Praça da Sé", origin_number: "100",
      origin_neighborhood: "Sé", origin_city: "São Paulo", origin_state: "SP")
    @seller.connect_superfrete!(access_token: "superfrete-token", sandbox: Marketplace::SuperfreteOauth.sandbox?,
      account: Marketplace::SuperfreteOauth::Account.new(id: "sf-account-1", email: users(:seller).email_address))
    @order = orders(:one)
    @order.update!(recipient_name: "Ana Souza", recipient_cpf: "52998224725")
    @seller_order = seller_orders(:one)
    @seller_order.update!(status: :confirmed)
    @shipment = Shipment.create!(seller_order: @seller_order, carrier: "Correios", service: "PAC", shipping_cents: 1500, estimated_days: 5)
  end

  def build_label(status: :draft, **attributes)
    @shipment.shipping_labels.create!({
      status: status, service_code: 1, service_name: "PAC", quoted_price_cents: 2351,
      height_cm: 10, width_cm: 16, length_cm: 24, weight_grams: 500,
      sandbox: @seller.superfrete_sandbox?, superfrete_account_id: @seller.superfrete_account_id,
      provider_order_id: (status.to_s == "draft" ? nil : "sf-order-1")
    }.merge(attributes))
  end
end
