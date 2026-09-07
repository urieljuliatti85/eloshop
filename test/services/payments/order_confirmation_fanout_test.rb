require "test_helper"

module Payments
  # O fan-out do pedido confirmado: cliente, ateliê e analytics. O que importa
  # aqui não é o conteúdo de cada aviso (cobertos nos testes de job/mailer) e
  # sim QUANDO eles são disparados — em particular, que um webhook repetido
  # não avise ninguém duas vezes.
  class OrderConfirmationFanoutTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper
    include ActionMailer::TestHelper

    def build_order_with_payment
      customer = Customer.create!(name: "Cliente", email: "#{SecureRandom.hex(4)}@example.com", password: "password123")
      address = customer.addresses.create!(street: "Rua", number: "1", neighborhood: "B", city: "C", state: "SP", zip_code: "00000-000")
      product = Product.create!(seller: sellers(:approved), name: "P", sku: "SKU-#{SecureRandom.hex(4)}", price_cents: 1000, stock_quantity: 5, currency: "BRL", status: "active")
      cart = Cart.create!(session_token: SecureRandom.hex(10))
      cart.cart_items.create!(product: product, quantity: 1)
      order = Checkout::CreateOrder.new(cart: cart, customer: customer, address: address, idempotency_key: SecureRandom.hex(10)).call
      payment = Authorize.new(order: order).call
      [ order, payment ]
    end

    def approve(payment, event_id: SecureRandom.hex(10))
      ProcessWebhook.new(event_id: event_id, external_id: payment.external_id, status: "approved").call
    end

    test "confirmar o pedido enfileira os três avisos" do
      _order, payment = build_order_with_payment

      assert_enqueued_jobs 3 do
        approve(payment)
      end

      assert_enqueued_with(job: SendOrderConfirmationJob)
      assert_enqueued_with(job: NotifySellerOfOrderJob)
      assert_enqueued_with(job: RecordOrderAnalyticsJob)
    end

    # A garantia que sustenta o §28/§29: o mesmo evento chegando duas vezes
    # não pode mandar dois e-mails de confirmação.
    test "webhook repetido não reenfileira nada" do
      _order, payment = build_order_with_payment
      event_id = SecureRandom.hex(10)

      approve(payment, event_id: event_id)

      assert_no_enqueued_jobs do
        approve(payment, event_id: event_id)
      end
    end

    # Evento diferente sobre um pedido já confirmado (retry do gateway com id
    # novo, ou a confirmação síncrona do cartão chegando junto do webhook)
    # também não pode duplicar: a guarda é a máquina de estados, não o id.
    test "segundo evento distinto sobre pedido já confirmado não reenfileira" do
      _order, payment = build_order_with_payment

      approve(payment)

      assert_no_enqueued_jobs do
        approve(payment)
      end
    end

    test "pagamento recusado não avisa ninguém" do
      _order, payment = build_order_with_payment

      assert_no_enqueued_jobs do
        ProcessWebhook.new(event_id: SecureRandom.hex(10), external_id: payment.external_id, status: "declined").call
      end
    end

    # Os avisos são enfileirados, nunca entregues dentro da transação: a
    # compra não pode depender da entrega imediata de um e-mail (§50). Se a
    # entrega fosse síncrona aqui, um SMTP fora do ar derrubaria a
    # confirmação do pagamento junto.
    test "confirmar não entrega e-mail de forma síncrona" do
      order, payment = build_order_with_payment

      assert_no_emails do
        approve(payment)
      end

      assert order.reload.confirmed?
      assert payment.reload.paid?
      assert_enqueued_jobs 3
    end

    # Executar o fan-out de verdade tem de produzir os dois e-mails: um para
    # o cliente, um para o ateliê. Cobre a montagem real das duas mensagens.
    test "executar os jobs entrega os dois e-mails" do
      order, payment = build_order_with_payment

      assert_emails 2 do
        perform_enqueued_jobs { approve(payment) }
      end

      recipients = ActionMailer::Base.deliveries.last(2).flat_map(&:to)
      assert_includes recipients, order.customer.email
      assert_includes recipients, sellers(:approved).users.order(:created_at).first.email_address
    end
  end
end
