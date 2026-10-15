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

  # A área atual usa tinta escura: o vermelho fica para o que pede ação
  # (Mercado Pago obrigatório, chave PIX pendente).
  it "marks the sidebar item of the current area in a non-alarm color" do
    get seller_products_path
    expect(current_labels).to eq([ "Produtos" ])
    expect(Nokogiri::HTML(response.body).at_css("aside a[aria-current='page']")["class"]).to include("bg-stone-900")
  end

  it "groups the menu into operation, catalog and setup" do
    get seller_root_path
    groups = Nokogiri::HTML(response.body).css("aside nav > p").map { |label| label.text.strip }
    expect(groups).to eq([ "Operação", "Catálogo", "Configuração" ])
  end

  it "shows the PIX key item as pending until the seller confirms the key" do
    get seller_root_path
    pix_link = Nokogiri::HTML(response.body).at_css("aside a[href='#{seller_pix_key_guide_path}']")
    expect(pix_link.text).to include("Pendente")
    expect(pix_link["class"]).not_to include("bg-red")

    seller.update_column(:pix_key_confirmed_at, Time.current)
    get seller_root_path
    pix_link = Nokogiri::HTML(response.body).at_css("aside a[href='#{seller_pix_key_guide_path}']")
    expect(pix_link.text).to include("✓ Cadastrada")
  end

  it "marks only the most specific area" do
    get new_seller_product_path
    expect(current_labels).to eq([ "Novo produto" ])
  end
end
