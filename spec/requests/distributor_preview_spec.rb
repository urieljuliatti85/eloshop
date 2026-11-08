# frozen_string_literal: true

require "rails_helper"

# Prévia de armarinho (/armarinhos/previa-eloshop) é só exemplo visual em
# produção: nunca pode ter insumo comprável, usuário com e-mail real nem o
# selo "verificado" (pedido de 2026-11-07, alternativa "exemplo sem compra").
RSpec.describe "Distributor preview", type: :request do
  let!(:preview) do
    Seller.find_by(slug: Seller::PREVIEW_DISTRIBUTOR_SLUG) ||
      Seller.create!(name: "Prévia de Armarinho EloShop", slug: Seller::PREVIEW_DISTRIBUTOR_SLUG,
        owner_full_name: "Prévia EloShop", cpf: generate_valid_cpf,
        kind: "distributor", status: :pending, showcased_at: Time.current,
        notice_text: "Prévia demonstrativa do pré-cadastro de armarinhos.")
  end

  it "shows the preview labelled as an example, without the verified badge or invoice flag" do
    get distributor_store_path(preview.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Exemplo")
    expect(response.body).not_to include("Armarinho verificado")
    expect(response.body).not_to include("Nota fiscal:")
  end

  it "never exposes a purchasable supply in the preview" do
    product = preview.products.create!(name: "Item de teste", price_cents: 1000, stock_quantity: 5,
      status: :draft, sale_unit: :pack)

    expect(product.available_for_purchase?).to be(false)
    expect(preview.products.active).to be_empty
  end

  it "has no user account tied to the preview" do
    expect(User.where(seller_id: preview.id)).to be_empty
  end
end
