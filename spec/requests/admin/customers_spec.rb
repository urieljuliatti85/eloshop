# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin customers", type: :request do
  let(:user) { User.create!(email_address: "customer-admin@example.com", password: "password", password_confirmation: "password") }
  let!(:customer) { Customer.create!(name: "Maria Cliente", email: "maria-cliente-admin@example.com", password: "password123") }

  describe "GET /admin/customers" do
    it "redirects unauthenticated users to login" do
      get admin_customers_path

      expect(response).to redirect_to(new_session_path)
    end

    it "lists customers" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      I18n.with_locale(:"pt-BR") { get admin_customers_path }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(customer.name)
      expect(response.body).to include(I18n.l(customer.created_at.to_date, format: :short, locale: :"pt-BR"))
    end

    it "filters by name or email" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      other = Customer.create!(name: "João Outro", email: "joao-cliente-admin@example.com", password: "password123")

      get admin_customers_path, params: { query: "maria" }

      expect(response.body).to include(customer.name)
      expect(response.body).not_to include(other.name)
    end
  end

  describe "GET /admin/customers/:id" do
    it "shows the customer with addresses and order history" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      customer.addresses.create!(street: "Rua Teste", number: "10", neighborhood: "Centro", city: "São Paulo", state: "SP", zip_code: "01000-000")
      order = Order.create!(
        customer: customer, status: "pending", subtotal_cents: 1_000, shipping_cents: 500, total_cents: 1_500,
        shipping_address_snapshot: { street: "Rua", number: "1" }, idempotency_key: SecureRandom.uuid
      )

      get admin_customer_path(customer)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Rua Teste")
      expect(response.body).to include(order.id.to_s)
    end
  end
end
