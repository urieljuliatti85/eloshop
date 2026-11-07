require "test_helper"

class SellerOnboardingMailerTest < ActionMailer::TestCase
  test "tells the platform which seller waits for approval and links to the admin" do
    seller = sellers(:pending)

    mail = SellerOnboardingMailer.awaiting_approval(seller)

    assert_equal [ "contato@eloshop.shop" ], mail.to
    assert_match seller.name, mail.subject
    assert_match "KYC", mail.body.encoded
    assert_match "/admin/sellers/#{seller.slug}", mail.body.encoded
  end

  test "tells the platform when the seller waiting for approval is a distributor" do
    distributor = Seller.create!(name: "Fios Aguardando", owner_full_name: "Dona dos Fios", cpf: "52998224725", kind: "distributor")

    mail = SellerOnboardingMailer.awaiting_approval(distributor)

    assert_includes mail.text_part.body.to_s, "(armarinho)"
    assert_includes mail.text_part.body.to_s, "Abrir o armarinho no admin"
    assert_not_includes mail.html_part.body.to_s, "ateliê"
  end
end
