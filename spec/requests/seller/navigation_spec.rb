require "rails_helper"

RSpec.describe "Seller panel navigation", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Menu", owner_full_name: "Proprietário Teste", cpf: "12000010601") }
  let(:user) { User.create!(email_address: "menu@example.com", password: "password123", role: :seller, seller: seller) }

  before { sign_in_as(user) }

  # O menu aparece duas vezes (barra lateral e hambúrguer); só interessa qual
  # área está marcada como atual.
  def current_labels
    Nokogiri::HTML(response.body).css("a[aria-current='page']").map { |link| link.text.strip.split("\n").first }.uniq
  end

  it "marks the overview only on the root page" do
    get seller_root_path
    expect(current_labels).to eq([ "Visão geral" ])
  end

  it "marks the sidebar item of the current area in the brand color" do
    get seller_products_path
    expect(current_labels).to eq([ "Produtos" ])
    expect(Nokogiri::HTML(response.body).at_css("aside a[aria-current='page']")["class"]).to include("bg-brand-500")
  end

  it "marks only the most specific area" do
    get new_seller_product_path
    expect(current_labels).to eq([ "Novo produto" ])
  end
end
