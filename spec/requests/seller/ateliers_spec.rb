# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Seller atelier", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê do Vendedor", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "dono@eloshop.test", password: "password123", role: :seller, seller: seller) }

  describe "GET /painel/atelie" do
    it "requires a signed-in seller" do
      get seller_atelier_path

      expect(response).to redirect_to(new_session_path)
    end

    # O admin tem painel próprio e não tem ateliê.
    it "keeps an admin out" do
      sign_in_as(User.create!(email_address: "admin-atelie@eloshop.test", password: "password123"))

      get seller_atelier_path

      expect(response).to redirect_to(new_session_path)
    end

    it "shows the seller's own data" do
      sign_in_as(user)

      get seller_atelier_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(seller.name)
    end

    # A área do painel deriva o escopo da sessão: o vendedor nunca vê o
    # ateliê de outro, nem trocando qualquer coisa na URL.
    it "never shows another seller's data" do
      other = Seller.create!(name: "Ateliê Alheio", status: :approved, approved_at: Time.current)
      sign_in_as(user)

      get seller_atelier_path

      expect(response.body).not_to include(other.name)
    end
  end

  describe "PATCH /painel/atelie" do
    it "renames the atelier" do
      sign_in_as(user)

      patch seller_atelier_path, params: { seller: { name: "Novo Nome" } }

      expect(seller.reload.name).to eq("Novo Nome")
    end

    it "rejects a blank name" do
      sign_in_as(user)

      patch seller_atelier_path, params: { seller: { name: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(seller.reload.name).to eq("Ateliê do Vendedor")
    end

    # `slug` está nas URLs públicas dos produtos: trocá-lo quebraria links já
    # compartilhados. `status` é decisão da plataforma, não do vendedor.
    it "ignores slug and status sent by the seller" do
      sign_in_as(user)
      original_slug = seller.slug

      patch seller_atelier_path, params: { seller: { name: "Com Extras", slug: "invadido", status: "suspended" } }

      seller.reload
      expect(seller.slug).to eq(original_slug)
      expect(seller).to be_approved
    end
  end
end
