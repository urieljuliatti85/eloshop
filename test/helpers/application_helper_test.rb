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

  test "field_error shows the server message with the id the required-fields controller uses" do
    product = Product.new
    product.errors.add(:name, "não pode ficar em branco")
    form = ActionView::Helpers::FormBuilder.new(:product, product, self, {})

    html = field_error(form, :name)

    assert_includes html, 'id="product_name_error"'
    assert_includes html, 'class="field-error"'
    assert_includes html, "não pode ficar em branco"
    assert_equal({ invalid: true, describedby: "product_name_error" }, field_error_aria(form, :name))
  end

  test "field_error reads the model attribute behind money and association fields" do
    product = Product.new
    product.errors.add(:price_cents, "deve ser maior ou igual a 0")
    product.errors.add(:seller, "é obrigatório(a)")
    form = ActionView::Helpers::FormBuilder.new(:product, product, self, {})

    assert_includes field_error(form, :price), "deve ser maior ou igual a 0"
    assert_includes field_error(form, :seller_id), "é obrigatório(a)"
  end

  test "field_error renders nothing for a field without errors" do
    form = ActionView::Helpers::FormBuilder.new(:product, Product.new, self, {})

    assert_nil field_error(form, :sku)
    assert_equal({}, field_error_aria(form, :sku))
  end
end
