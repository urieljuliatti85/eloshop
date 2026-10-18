# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Seller theme", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê do Vendedor", owner_full_name: "Proprietário Teste", cpf: "11555563805", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "dono@eloshop.test", password: "password123", role: :seller, seller: seller) }

  describe "GET /painel/atelie/tema/edit" do
    it "requires a signed-in seller" do
      get edit_seller_theme_path

      expect(response).to redirect_to(seller_login_path)
    end

    it "keeps an admin out" do
      sign_in_as(User.create!(email_address: "admin-tema@eloshop.test", password: "password123"))

      get edit_seller_theme_path

      expect(response).to redirect_to(seller_login_path)
    end

    it "renders the editor with palettes, fonts, layouts and presets" do
      sign_in_as(user)

      get edit_seller_theme_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Oliva", "Clássica", "Destaque", "Minimalista", "Pré-visualização")
    end
  end

  describe "PATCH /painel/atelie/tema" do
    it "saves palette, font, layout and hero" do
      sign_in_as(user)

      patch seller_theme_path, params: { seller: { theme_palette: "oceano", theme_font: "classica", theme_layout: "destaque", theme_hero: "compacto" } }

      expect(response).to redirect_to(edit_seller_theme_path)
      seller.reload
      expect([ seller.theme_palette, seller.theme_font, seller.theme_layout, seller.theme_hero ]).to eq(%w[oceano classica destaque compacto])
    end

    it "rejects values outside the closed catalog" do
      sign_in_as(user)

      patch seller_theme_path, params: { seller: { theme_palette: "red; background:url(x)" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(seller.reload.theme_palette).to eq("terracota")
    end

    it "saves logo, cover and footer text" do
      sign_in_as(user)

      patch seller_theme_path, params: { seller: {
        footer_text: "Produção às terças.",
        logo: fixture_file_upload("sample.png", "image/png"),
        cover_image: fixture_file_upload("sample.png", "image/png")
      } }

      expect(response).to redirect_to(edit_seller_theme_path)
      seller.reload
      expect(seller.logo).to be_attached
      expect(seller.cover_image).to be_attached
      expect(seller.footer_text).to eq("Produção às terças.")
    end

    it "rejects a non-image logo" do
      sign_in_as(user)

      patch seller_theme_path, params: { seller: {
        logo: Rack::Test::UploadedFile.new(StringIO.new("<svg/>"), "image/svg+xml", original_filename: "logo.svg")
      } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(seller.reload.logo).not_to be_attached
    end

    it "removes the current images on request" do
      sign_in_as(user)
      seller.logo.attach(fixture_file_upload("sample.png", "image/png"))
      seller.cover_image.attach(fixture_file_upload("sample.png", "image/png"))

      patch seller_theme_path, params: { seller: { footer_text: "" }, remove_logo: "1" }

      seller.reload
      expect(seller.logo).not_to be_attached
      expect(seller.cover_image).to be_attached
    end

    it "ignores a seller_id param and only touches the signed-in seller" do
      other = Seller.create!(name: "Ateliê Alheio", owner_full_name: "Proprietário Teste", cpf: "11666675539", status: :approved, approved_at: Time.current)
      sign_in_as(user)

      patch seller_theme_path, params: { seller_id: other.id, seller: { footer_text: "Meu rodapé", theme_palette: "ameixa" } }

      expect(other.reload.footer_text).to be_nil
      expect(other.theme_palette).to eq("terracota")
      expect(seller.reload.theme_palette).to eq("ameixa")
    end
  end
end
