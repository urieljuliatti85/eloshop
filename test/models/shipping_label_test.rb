require "test_helper"

class ShippingLabelTest < ActiveSupport::TestCase
  include ShippingLabelTestHelper

  setup { prepare_label_scenario }

  test "advances only from the expected state, so two workers cannot advance it twice" do
    label = build_label(status: :cart_created)
    stale = ShippingLabel.find(label.id)

    assert label.advance!(from: :cart_created, to: :purchasing)
    assert_not stale.advance!(from: :cart_created, to: :purchasing)
    assert label.reload.purchasing?
  end

  test "recognizes a purchase refused for lack of wallet balance by SuperFrete's message" do
    label = build_label(status: :failed, failure_message: "Sem saldo na carteira! Utilize o app para recarregar a carteira ou pagar a etiqueta com cartão de crédito.")
    assert label.failed_for_lack_of_balance?

    label.failure_message = "Campo CPF/CNPJ do destinatário é obrigatório."
    assert_not label.failed_for_lack_of_balance?
  end

  test "rejects transitions the state machine does not allow" do
    label = build_label(status: :purchased)

    assert_raises(ShippingLabel::InvalidTransition) { label.advance!(from: :purchased, to: :purchasing) }
  end

  test "the database keeps one active label per shipment" do
    build_label(status: :purchased)

    assert_raises(ActiveRecord::RecordNotUnique) { build_label(status: :cart_created, provider_order_id: "sf-order-2") }
  end

  test "a cancelled or failed label does not block a new one" do
    build_label(status: :cancelled)
    build_label(status: :failed, provider_order_id: "sf-order-2")

    assert build_label(status: :draft)
  end
end
