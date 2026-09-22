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
end
