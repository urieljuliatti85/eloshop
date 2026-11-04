require "rails_helper"

RSpec.describe "Seller category suggestions", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê Um", owner_full_name: "Proprietário Teste", cpf: generate_valid_cpf, status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "seller-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller) }
  let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

  def suggest(name, headers: turbo)
    post seller_category_suggestions_path, params: { category_suggestion: { name: name } }, headers: headers
  end

  context "when signed in as a seller" do
    before { sign_in_as(user) }

    it "shows the suggestion field under the category, wired to a sibling form" do
      get new_seller_product_path

      expect(response).to have_http_status(:ok)
      html = Nokogiri::HTML(response.body)
      sibling = html.at_css("form#category-suggestion-form")
      field = html.at_css("input#category_suggestion_name")

      expect(sibling).to be_present
      expect(sibling.ancestors("form")).to be_empty
      expect(sibling["action"]).to eq(seller_category_suggestions_path)
      expect(field["form"]).to eq("category-suggestion-form")
      expect(field.ancestors("form").first["id"]).not_to eq("category-suggestion-form")
      expect(response.body).to include("Não tem a categoria que procura?")
    end

    it "records the suggestion for the signed-in seller and answers with a turbo stream" do
      expect { suggest("Macramê de parede") }.to change(CategorySuggestion, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('target="category-suggestion"', "Recebemos a sugestão")
      expect(CategorySuggestion.last.sellers).to eq([ seller ])
    end

    it "ignores any seller id sent by the browser" do
      other = Seller.create!(name: "Ateliê Dois", owner_full_name: "Outro", cpf: generate_valid_cpf, status: :approved, approved_at: Time.current)

      post seller_category_suggestions_path, params: { category_suggestion: { name: "Vitral", seller_id: other.id }, seller_id: other.id }, headers: turbo

      expect(CategorySuggestion.last.sellers).to eq([ seller ])
    end

    it "points to the existing category instead of creating a suggestion" do
      Category.create!(name: "Cerâmica")

      expect { suggest("ceramica") }.not_to change(CategorySuggestion, :count)
      expect(response.body).to include("A categoria &quot;Cerâmica&quot; já existe")
    end

    it "tells the seller when they already suggested the same name" do
      suggest("Cestaria")
      suggest("  cestaria ")

      expect(response.body).to include("Você já sugeriu")
      expect(CategorySuggestion.count).to eq(1)
    end

    it "keeps the typed value and explains an invalid name" do
      suggest("!!!")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("precisa ter letras ou números", 'value="!!!"')
    end

    it "answers a name that grows on normalization with a message, not a server error" do
      suggest("Æ" * CategorySuggestion::NAME_MAX_LENGTH)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(CategorySuggestion.count).to eq(0)
    end

    it "limits suggestions per seller" do
      5.times { |i| suggest("Categoria #{i}") }
      suggest("Categoria extra")

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("Muitas sugestões")
      expect(CategorySuggestion.count).to eq(5)
    end

    it "falls back to a redirect with a flash without Turbo" do
      suggest("Origami", headers: {})

      expect(response).to redirect_to(seller_products_path)
      expect(flash[:notice]).to include("Recebemos a sugestão")
    end
  end

  it "does not accept suggestions from an admin" do
    admin =User.create!(email_address: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
    sign_in_as(admin)

    expect { suggest("Vitral") }.not_to change(CategorySuggestion, :count)
  end

  it "requires a signed-in seller" do
    expect { suggest("Vitral") }.not_to change(CategorySuggestion, :count)
    expect(response).to redirect_to(seller_login_path)
  end
end
