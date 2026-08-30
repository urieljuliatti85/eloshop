# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Addresses", type: :request do
  let(:customer) { Customer.create!(name: "Cliente address", email: "address@example.com", password: "password123") }

  describe "GET /addresses/new" do
    it "redirects unauthenticated visitors to customer login" do
      get new_address_path

      expect(response).to redirect_to(new_customer_session_path)
    end

    it "allows an authenticated customer to register an address" do
      post customer_session_path, params: { email: customer.email, password: "password123" }

      expect do
        post addresses_path, params: {
          address: {
            street: "Rua Nova",
            number: "10",
            neighborhood: "Bairro",
            city: "Cidade",
            state: "SP",
            zip_code: "00000-000"
          }
        }
      end.to change(Address, :count).by(1)

      expect(response).to redirect_to(root_path)
      expect(Address.last.customer).to eq(customer)
    end

    it "does not admit an admin session as customer authentication" do
      user = User.create!(email_address: "admin-address@example.com", password: "password", password_confirmation: "password")
      post session_path, params: { email_address: user.email_address, password: "password" }

      get new_address_path

      expect(response).to redirect_to(new_customer_session_path)
    end
  end
end
