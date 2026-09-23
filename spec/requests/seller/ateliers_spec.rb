# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Seller atelier", type: :request do
  let(:seller) { Seller.create!(name: "Ateliê do Vendedor", owner_full_name: "Proprietário Teste", cpf: "11555563805", status: :approved, approved_at: Time.current) }
  let(:user) { User.create!(email_address: "dono@eloshop.test", password: "password123", role: :seller, seller: seller) }

  describe "GET /painel/atelie" do
    it "requires a signed-in seller" do
      get seller_atelier_path

      expect(response).to redirect_to(seller_login_path)
    end

    # O admin tem painel próprio e não tem ateliê.
    it "keeps an admin out" do
      sign_in_as(User.create!(email_address: "admin-atelie@eloshop.test", password: "password123"))

      get seller_atelier_path

      expect(response).to redirect_to(seller_login_path)
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
      other = Seller.create!(name: "Ateliê Alheio", owner_full_name: "Proprietário Teste", cpf: "11666675539", status: :approved, approved_at: Time.current)
      sign_in_as(user)

      get seller_atelier_path

      expect(response.body).not_to include(other.name)
    end

    it "shows a call to action to register the origin address when missing" do
      sign_in_as(user)

      get seller_atelier_path

      expect(response.body).to include("Cadastrar endereço")
    end

    it "hides the call to action once the origin address is complete" do
      seller.update!(
        origin_zip_code: "88010-000", origin_street: "Rua das Flores",
        origin_number: "10", origin_neighborhood: "Centro", origin_city: "Florianópolis", origin_state: "SC"
      )
      sign_in_as(user)

      get seller_atelier_path

      expect(response.body).not_to include("Cadastrar endereço")
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

    it "saves the origin address" do
      sign_in_as(user)

      patch seller_atelier_path, params: { seller: {
        name: seller.name, origin_zip_code: "88010-000", origin_street: "Rua das Flores",
        origin_number: "10", origin_neighborhood: "Centro", origin_city: "Florianópolis", origin_state: "SC"
      } }

      seller.reload
      expect(seller.origin_zip_code).to eq("88010000")
      expect(seller).to be_origin_address_complete
    end

    # Meio endereço não despacha nada.
    it "rejects a partial origin address" do
      sign_in_as(user)

      patch seller_atelier_path, params: { seller: { name: seller.name, origin_city: "Florianópolis" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(seller.reload.origin_city).to be_nil
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

    # Vendedores cadastrados antes deste campo existir não têm CPF/nome do
    # proprietário — a validação só é obrigatória na criação (ver
    # Seller#owner_full_name/cpf), e o painel é onde eles completam o dado.
    it "lets a seller without owner data fill it in later" do
      legacy_seller = Seller.create!(name: "Ateliê Legado", owner_full_name: "Temporário", cpf: "384.756.192-82", status: :approved, approved_at: Time.current)
      # Simula um cadastro anterior a este campo existir: `update_columns`
      # ignora validação de propósito, para reproduzir o estado real de um
      # `Seller` gravado antes de owner_full_name/cpf existirem.
      legacy_seller.update_columns(owner_full_name: nil, cpf_ciphertext: nil, cpf_hash: nil)
      legacy_user = User.create!(email_address: "legado@eloshop.test", password: "password123", role: :seller, seller: legacy_seller)
      sign_in_as(legacy_user)

      patch seller_atelier_path, params: { seller: {
        name: legacy_seller.name, owner_full_name: "Dono Retroativo", cpf: "715.928.463-19"
      } }

      legacy_seller.reload
      expect(legacy_seller.owner_full_name).to eq("Dono Retroativo")
      expect(legacy_seller.masked_cpf).to eq("***.***.***-19")
    end

    it "keeps the previously stored CPF when the field is left blank" do
      sign_in_as(user)
      original_masked_cpf = seller.masked_cpf

      patch seller_atelier_path, params: { seller: { name: seller.name, cpf: "" } }

      expect(seller.reload.masked_cpf).to eq(original_masked_cpf)
    end

    it "rejects an invalid CPF without touching the previously stored one" do
      sign_in_as(user)
      original_masked_cpf = seller.masked_cpf

      patch seller_atelier_path, params: { seller: { name: seller.name, cpf: "111.111.111-11" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(seller.reload.masked_cpf).to eq(original_masked_cpf)
    end
  end
end
