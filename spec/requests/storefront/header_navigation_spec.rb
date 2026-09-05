# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Header navigation", type: :request do
  # O item ativo vem do controller, não da URL exata: a página de um produto
  # continua marcando "Loja".
  def active_labels
    response.body.scan(/aria-current="page"[^>]*>([^<]+)</).flatten.uniq
  end

  it "marks Início on the home page" do
    get root_path

    expect(active_labels).to eq([ "Início" ])
  end

  it "marks Loja on the catalog" do
    get products_path

    expect(active_labels).to eq([ "Loja" ])
  end

  it "marks Loja on a product page" do
    product = Product.create!(seller: approved_seller, name: "Vaso nav", sku: "NAV-001",
      price_cents: 8_990, stock_quantity: 2, currency: "BRL", status: :active)

    get product_path(product.seller, product.slug)

    expect(active_labels).to eq([ "Loja" ])
  end

  it "marks Contato on the contact form" do
    get new_contact_path

    expect(active_labels).to eq([ "Contato" ])
  end
end
