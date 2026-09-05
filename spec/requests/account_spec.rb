# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Customer account area", type: :request do
  let(:customer) { Customer.create!(name: "Ana Souza", email: "ana-conta@eloshop.test", password: "password123") }
  let(:other) { Customer.create!(name: "Beto Alheio", email: "beto-conta@eloshop.test", password: "password123") }

  def sign_in(who = customer)
    post customer_session_path, params: { email: who.email, password: "password123" }
  end

  def build_address(owner, street: "Rua das Flores")
    owner.addresses.create!(street: street, number: "10", neighborhood: "Centro",
      city: "Florianópolis", state: "SC", zip_code: "88010-000")
  end

  describe "GET /minha-conta" do
    it "requires a signed-in customer" do
      get account_root_path

      expect(response).to redirect_to(new_customer_session_path)
    end

    it "shows the account summary" do
      sign_in
      build_address(customer)

      get account_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(customer.name)
      expect(response.body).to include(customer.email)
    end
  end

  describe "addresses" do
    it "lists only the signed-in customer's addresses" do
      mine = build_address(customer, street: "Rua Minha")
      theirs = build_address(other, street: "Rua Alheia")
      sign_in

      get addresses_path

      expect(response.body).to include(mine.street)
      expect(response.body).not_to include(theirs.street)
    end

    it "updates an address" do
      address = build_address(customer)
      sign_in

      patch address_path(address), params: { address: { street: "Rua Nova", number: "20", neighborhood: "Centro", city: "Florianópolis", state: "SC", zip_code: "88010-000" } }

      expect(address.reload.street).to eq("Rua Nova")
    end

    it "removes an address" do
      address = build_address(customer)
      sign_in

      expect { delete address_path(address) }.to change(Address, :count).by(-1)
    end

    # Um id trocado na URL não pode alcançar o endereço de outra pessoa.
    it "does not reach another customer's address" do
      theirs = build_address(other, street: "Rua Alheia")
      sign_in

      patch address_path(theirs), params: { address: { street: "Invadida" } }

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.street).to eq("Rua Alheia")
    end
  end

  describe "profile" do
    it "updates name and email without touching the password" do
      sign_in

      patch account_profile_path, params: { customer: { name: "Ana Atualizada", email: "ana-nova@eloshop.test" } }

      customer.reload
      expect(customer.name).to eq("Ana Atualizada")
      expect(customer.email).to eq("ana-nova@eloshop.test")
      expect(customer.authenticate("password123")).to be_truthy
    end

    it "changes the password when the current one is confirmed" do
      sign_in

      patch account_profile_path, params: { customer: {
        name: customer.name, email: customer.email,
        password: "novasenha123", password_confirmation: "novasenha123",
        current_password: "password123"
      } }

      expect(customer.reload.authenticate("novasenha123")).to be_truthy
    end

    # Sem isto, uma sessão roubada trocaria a senha e tomaria a conta.
    it "refuses a password change without the current password" do
      sign_in

      patch account_profile_path, params: { customer: {
        name: customer.name, email: customer.email,
        password: "invadida123", password_confirmation: "invadida123",
        current_password: "errada"
      } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(customer.reload.authenticate("password123")).to be_truthy
    end
  end
end
