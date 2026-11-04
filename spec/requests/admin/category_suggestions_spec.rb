require "rails_helper"

RSpec.describe "Admin category suggestions", type: :request do
  let(:admin) { User.create!(email_address: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin) }
  let(:seller) { approved_seller }
  let(:other_seller) do
    Seller.create!(name: "Ateliê Dois #{SecureRandom.hex(3)}", owner_full_name: "Outra", cpf: generate_valid_cpf, status: :approved, approved_at: Time.current).tap do |s|
      User.create!(email_address: "dois-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: s)
    end
  end
  let(:suggestion) do
    CategorySuggestion.suggest!(seller: seller, name: "Macramê").suggestion.tap do |s|
      CategorySuggestion.suggest!(seller: other_seller, name: "macrame")
      s.reload
    end
  end

  context "as an admin" do
    before { sign_in_as(admin) }

    it "lists the suggestion with every seller who asked and their e-mails" do
      suggestion

      get admin_category_suggestions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Macramê", seller.name, other_seller.name, other_seller.users.first.email_address, "Aceitar", "Recusar")
    end

    it "offers only categories that appear in the store as the parent" do
      disabled = Category.create!(name: "Desligada", active: false)
      Category.create!(name: "Sob desligada", parent: disabled)
      Category.create!(name: "Decoração")
      suggestion

      get admin_category_suggestions_path

      options = Nokogiri::HTML(response.body).css("select[name='category_suggestion[parent_id]'] option").map(&:text)
      expect(options).to include("Decoração")
      expect(options.grep(/Desligada/)).to be_empty
    end

    it "links to the suggestions from the categories page with the pending count" do
      suggestion

      get admin_categories_path

      expect(response.body).to include("Categorias sugeridas (1)")
    end

    it "accepts under the chosen parent with the corrected name and notifies each seller" do
      parent = Category.create!(name: "Decoração")

      expect do
        patch accept_admin_category_suggestion_path(suggestion), params: { category_suggestion: { name: "Macramê de parede", parent_id: parent.id } }
      end.to have_enqueued_job(NotifyCategorySuggestionDecisionJob).exactly(2).times

      expect(response).to redirect_to(admin_category_suggestions_path)
      expect(flash[:notice]).to include("Decoração > Macramê de parede")
      expect(suggestion.reload).to be_accepted
      expect(suggestion.category.parent).to eq(parent)
    end

    it "accepts as a top-level category when no parent is chosen" do
      patch accept_admin_category_suggestion_path(suggestion), params: { category_suggestion: { name: "Macramê", parent_id: "" } }

      expect(suggestion.reload.category.parent).to be_nil
    end

    it "explains a name that collides with another category and keeps the suggestion pending" do
      moda = Category.create!(name: "Moda")
      Category.create!(name: "Acessórios", parent: moda)

      expect do
        patch accept_admin_category_suggestion_path(suggestion), params: { category_suggestion: { name: "Acessorios", parent_id: "" } }
      end.not_to have_enqueued_job(NotifyCategorySuggestionDecisionJob)

      expect(flash[:alert]).to include("Moda > Acessórios")
      expect(suggestion.reload).to be_pending
    end

    it "deletes a category created from a suggestion and keeps the history on the list" do
      patch accept_admin_category_suggestion_path(suggestion), params: { category_suggestion: { name: "Macramê", parent_id: "" } }
      category = suggestion.reload.category

      delete admin_category_path(category)

      expect(response).to redirect_to(admin_categories_path)
      expect(Category.exists?(category.id)).to be(false)
      get admin_category_suggestions_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("a categoria foi apagada depois")
    end

    it "removes an admin who decided a suggestion" do
      other_admin = User.create!(email_address: "decisor-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :admin)
      suggestion.reject!(admin: other_admin)

      delete admin_admin_path(other_admin)

      expect(response).to redirect_to(admin_admins_path)
      expect(User.exists?(other_admin.id)).to be(false)
      expect(suggestion.reload).to be_rejected
    end

    it "rejects and notifies; a second decision changes nothing" do
      expect do
        patch reject_admin_category_suggestion_path(suggestion)
      end.to have_enqueued_job(NotifyCategorySuggestionDecisionJob).exactly(2).times
      expect(suggestion.reload).to be_rejected

      expect do
        patch reject_admin_category_suggestion_path(suggestion)
        patch accept_admin_category_suggestion_path(suggestion), params: { category_suggestion: { name: "Macramê", parent_id: "" } }
      end.not_to have_enqueued_job(NotifyCategorySuggestionDecisionJob)
      expect(flash[:alert]).to include("já tinha sido decidida")
      expect(suggestion.reload).to be_rejected
    end
  end

  context "as a seller" do
    before { sign_in_as(seller.users.first) }

    it "cannot see or decide suggestions" do
      get admin_category_suggestions_path
      expect(response).not_to have_http_status(:ok)

      patch accept_admin_category_suggestion_path(suggestion), params: { category_suggestion: { name: "Macramê", parent_id: "" } }
      patch reject_admin_category_suggestion_path(suggestion)

      expect(suggestion.reload).to be_pending
    end
  end

  it "requires a signed-in admin" do
    get admin_category_suggestions_path

    expect(response).to redirect_to(new_session_path)
  end
end
