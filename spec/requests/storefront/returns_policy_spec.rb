# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Returns policy", type: :request do
  before { clear_product_data! }

  it "explains withdrawal, made-to-order, defects and refunds without requiring login" do
    get returns_policy_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Trocas, devoluções e arrependimento")
    expect(response.body).to include("7 dias corridos a contar do recebimento")
    expect(response.body).to include("até o ateliê iniciar a produção")
    expect(response.body).to include("30 dias do recebimento")
    expect(response.body).to include("2 dias úteis")
    expect(response.body).to include("contato@eloshop.shop")
  end

  it "is linked from the footer and from the refund answer in How it works" do
    get root_path
    expect(Nokogiri::HTML(response.body).css("footer a").map { |a| a["href"] }).to include(returns_policy_path)

    get how_it_works_path
    expect(response.body).to include(returns_policy_path)
  end

  it "warns on a made-to-order product page, but not on a ready-made one" do
    made_to_order = Product.create!(
      seller: approved_seller, name: "Peça sob encomenda", sku: "POLICY-MTO-001", price_cents: 8_990, currency: "BRL",
      status: :active, availability_type: :made_to_order, production_time_min_days: 7, production_time_max_days: 10
    )
    ready_made = Product.create!(seller: approved_seller, name: "Peça pronta", sku: "POLICY-RDY-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)

    get product_path(made_to_order.seller, made_to_order.slug)
    expect(response.body).to include("desistir da compra até o ateliê iniciar a produção")
    expect(response.body).to include(returns_policy_path(anchor: "sob-encomenda"))

    get product_path(ready_made.seller, ready_made.slug)
    expect(response.body).not_to include("até o ateliê iniciar a produção")
  end
end
