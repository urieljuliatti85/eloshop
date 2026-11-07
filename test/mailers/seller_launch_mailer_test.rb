require "test_helper"

class SellerLaunchMailerTest < ActionMailer::TestCase
  # Achado do QA (2026-11-07): o distribuidor recebia "Seu ateliê foi
  # aprovado" com link para /artesaos/:slug, que para ele responde 404
  # (ADR 007, vitrine só de ateliê).
  test "the approval e-mail of a distributor talks about the distributor and links to its panel" do
    distributor = Seller.create!(name: "Fios Aprovados", owner_full_name: "Dona dos Fios", cpf: "52998224725",
      kind: "distributor", status: :approved, approved_at: Time.current)

    mail = SellerLaunchMailer.approved(distributor, "fios@example.com")

    assert_match "Seu armarinho foi aprovado", mail.subject
    [ mail.text_part.body.to_s, mail.html_part.body.to_s ].each do |body|
      assert_includes body, "/atacado/painel"
      assert_not_includes body, "/artesaos/"
      assert_not_includes body, "Seu ateliê"
    end
  end

  test "the approval e-mail of an atelier keeps linking to its public page" do
    seller = sellers(:approved)

    mail = SellerLaunchMailer.approved(seller, "atelie@example.com")

    assert_match "Seu ateliê foi aprovado", mail.subject
    assert_includes mail.text_part.body.to_s, "/artesaos/#{seller.slug}"
  end
end
