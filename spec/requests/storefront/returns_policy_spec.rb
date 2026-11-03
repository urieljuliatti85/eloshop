# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Returns policy", type: :request do
  before { clear_product_data! }

  # Texto do Anexo I do parecer jurídico de 2026-10-29: as regras que o
  # parecer corrigiu não podem voltar por engano.
  it "publishes the lawyer-reviewed policy without requiring login" do
    get returns_policy_path

    expect(response).to have_http_status(:ok)
    body = Nokogiri::HTML(response.body).text.squish
    expect(body).to include("Política de Trocas, Devoluções, Cancelamentos e Reembolsos")
    expect(body).to include("7 (sete) dias corridos contados do recebimento do produto")
    expect(body).to include("O início da produção não implica, por si só, a perda automática do direito de arrependimento")
    expect(body).to include("30 (trinta) dias para produtos não duráveis", "90 (noventa) dias para produtos duráveis")
    expect(body).to include("não haverá cobrança de frete de retorno ao consumidor")
    expect(body).to include("2 (dois) dias úteis", "contato@eloshop.shop")
    expect(body).to include("não impedem o acesso aos órgãos de defesa do consumidor ou ao Poder Judiciário")
  end

  it "no longer limits withdrawal to the start of production nor lets the platform decide alone" do
    get returns_policy_path

    expect(response.body).not_to include("até o ateliê iniciar a produção")
    expect(response.body).not_to include("a EloShop decide")
    expect(response.body).not_to include("decide reembolsos e disputas")
  end

  it "is linked from the footer and from the refund answer in How it works" do
    get root_path
    expect(Nokogiri::HTML(response.body).css("footer a").map { |a| a["href"] }).to include(returns_policy_path)

    get how_it_works_path
    expect(response.body).to include(returns_policy_path)
  end

  it "explains to artisans who handles cancellations, with the Anexo II text" do
    get how_it_works_path(aba: "vende")

    body = Nokogiri::HTML(response.body).text.squish
    expect(body).to include("Quem cuida dos cancelamentos, devoluções e reembolsos?")
    expect(body).to include("Os ajustes financeiros internos não poderão reduzir o reembolso legalmente devido ao comprador.")
    expect(body).not_to include("decide reembolsos e disputas")
  end

  it "links the policy from a made-to-order product page without promising a withdrawal limit" do
    made_to_order = Product.create!(
      seller: approved_seller, name: "Peça sob encomenda", sku: "POLICY-MTO-001", price_cents: 8_990, currency: "BRL",
      status: :active, availability_type: :made_to_order, production_time_min_days: 7, production_time_max_days: 10
    )
    ready_made = Product.create!(seller: approved_seller, name: "Peça pronta", sku: "POLICY-RDY-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active)

    get product_path(made_to_order.seller, made_to_order.slug)
    expect(response.body).to include(returns_policy_path(anchor: "sob-encomenda"))
    expect(response.body).not_to include("até o ateliê iniciar a produção")

    get product_path(ready_made.seller, ready_made.slug)
    expect(response.body).not_to include(returns_policy_path(anchor: "sob-encomenda"))
  end
end
