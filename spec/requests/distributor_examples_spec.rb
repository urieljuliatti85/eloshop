# frozen_string_literal: true

require "rails_helper"

# Armarinhos de exemplo em produção (db/seeds/distributors.rb): aparecem na vitrine
# rotulados como "Exemplo", sem vendedor real por trás e sem compra.
RSpec.describe "Distributor examples", type: :request do
  before { load Rails.root.join("db/seeds/distributors.rb").to_s }

  it "lists the three examples on /armarinhos with the example and partner badges" do
    get distributors_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      CGI.escapeHTML("Armarinho Fios & Cores"), CGI.escapeHTML("Armarinho Tecidos & Estampas"),
      CGI.escapeHTML("Armarinho Aviamentos Criativos")
    )
    expect(response.body).to include("Exemplo", "Parceiro EloShop", "Nota fiscal: não emite")
  end

  it "shows at least two supplies on the store page" do
    get distributor_store_path("armarinho-fios-e-cores")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Insumos deste armarinho", "Fio de algodão macio", "Fio de malha premium")
  end

  it "shows the Botões de madeira page with its details and without a purchase action" do
    get supply_path("armarinho-aviamentos-criativos", "botoes-de-madeira")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Botões de madeira", "Exemplo", "Vendas de insumos em breve")
    expect(response.body).not_to include("Adicionar ao carrinho")
  end

  it "keeps the examples unpurchasable, without CPF and without a user account" do
    seller = Seller.find_by!(slug: "armarinho-aviamentos-criativos")
    product = Product.find_by!(sku: "SEED-BOTOES-MADEIRA-001")

    expect(product.available_for_purchase?).to be(false)
    expect(seller.cpf_hash).to be_nil
    expect(User.where(seller_id: seller.id)).to be_empty
  end

  it "marks the example store as noindex" do
    get distributor_store_path("armarinho-fios-e-cores")

    expect(response.body).to include('name="robots" content="noindex,nofollow"')
  end

  it "keeps the example armarinhos and their supplies out of the sitemap" do
    get sitemap_path

    expect(response.body).not_to include(distributor_store_url("armarinho-fios-e-cores"), supply_url("armarinho-aviamentos-criativos", "botoes-de-madeira"))
  end
end
