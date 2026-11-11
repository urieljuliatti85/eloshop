require "test_helper"

class ShippingLabelMailerTest < ActionMailer::TestCase
  include ShippingLabelTestHelper

  setup do
    prepare_label_scenario
    @label = build_label(status: :purchased, tracking_code: "AA123456789BR", posted_at: Time.current)
  end

  test "tells the team which atelier and why the order could not move" do
    mail = ShippingLabelMailer.needs_attention(@label, "o comprador pediu para desistir da compra", ShippingLabelMailer::TEAM_EMAIL)

    assert_equal [ ShippingLabelMailer::TEAM_EMAIL ], mail.to
    assert_match "foi postada", mail.subject
    assert_match "o comprador pediu para desistir da compra", mail.text_part.body.to_s
    assert_match @seller.name, mail.text_part.body.to_s
    assert_no_match @order.recipient_cpf, mail.html_part.body.to_s
  end

  test "tells the atelier the team will get in touch, with a link to the order" do
    mail = ShippingLabelMailer.needs_attention(@label, "motivo", users(:seller).email_address)

    assert_match "vai entrar em contato", mail.text_part.body.to_s
    assert_match "/painel/orders/#{@order.id}", mail.text_part.body.to_s
  end
end
