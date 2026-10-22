require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "payment_method_label shows PIX regardless of card fields" do
    payment = Payment.new(payment_method: "pix", installments: 1)

    assert_equal "PIX", payment_method_label(payment)
  end

  test "payment_method_label shows credit card without installments detail for a single installment" do
    payment = Payment.new(payment_method: "credit_card", installments: 1)

    assert_equal "Cartão de crédito", payment_method_label(payment)
  end

  test "payment_method_label includes installments count when parcelado" do
    payment = Payment.new(payment_method: "credit_card", installments: 3)

    assert_equal "Cartão de crédito · 3×", payment_method_label(payment)
  end

  test "payment_method_label includes brand and last four digits when present" do
    payment = Payment.new(payment_method: "credit_card", installments: 2, card_brand: "visa", card_last_four: "4242")

    assert_equal "Cartão de crédito · 2× · Visa •••• 4242", payment_method_label(payment)
  end

  test "checkout_delivery_estimate_label keeps the transport estimate without made-to-order pieces" do
    quote = Shipping::Quote.new(carrier: "Ateliê", service: "Entrega padrão", shipping_cents: 2000, estimated_days: 8)

    assert_equal "Até 8 dias úteis", checkout_delivery_estimate_label(quote, nil)
  end

  test "checkout_delivery_estimate_label adds production before transport" do
    quote = Shipping::Quote.new(carrier: "Ateliê", service: "Entrega padrão", shipping_cents: 2000, estimated_days: 8)

    assert_equal "Até 20 dias úteis (produção de até 12 + transporte de até 8)", checkout_delivery_estimate_label(quote, 12)
  end

  test "payment_summary_label only says paid after the payment is confirmed" do
    assert_includes payment_summary_label(Payment.new(payment_method: "pix", status: "pending", installments: 1)), "Forma de pagamento escolhida:"
    assert_includes payment_summary_label(Payment.new(payment_method: "pix", status: "paid", installments: 1)), "Pago com"
  end
end
