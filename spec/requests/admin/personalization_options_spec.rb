# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin personalization options", type: :request do
  let(:user) { User.create!(email_address: "personalization-admin@example.com", password: "password", password_confirmation: "password") }
  let(:product) { Product.create!(seller: approved_seller, name: "Vaso personalização", sku: "PERS-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active) }
  let(:option) { product.personalization_options.create!(label: "Nome gravado", required: true, max_length: 20) }

  describe "GET /admin/products/:product_id/personalization_options/new" do
    it "redirects unauthenticated users" do
      get new_admin_product_personalization_option_path(product)

      expect(response).to redirect_to(new_session_path)
    end

    it "allows authenticated admins" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      get new_admin_product_personalization_option_path(product)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /admin/products/:product_id/personalization_options" do
    it "creates a personalization option" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        post admin_product_personalization_options_path(product), params: {
          personalization_option: { label: "Cor da linha", required: false, max_length: 20 }
        }
      end.to change(PersonalizationOption, :count).by(1)

      expect(response).to redirect_to(admin_product_path(product))
    end

    it "rejects invalid labels" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        post admin_product_personalization_options_path(product), params: {
          personalization_option: { label: "", required: false, max_length: 20 }
        }
      end.not_to change(PersonalizationOption, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /admin/products/:product_id/personalization_options/:id" do
    it "updates a personalization option" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      patch admin_product_personalization_option_path(product, option), params: { personalization_option: { max_length: 50 } }

      expect(response).to redirect_to(admin_product_path(product))
      expect(option.reload.max_length).to eq(50)
    end
  end

  describe "DELETE /admin/products/:product_id/personalization_options/:id" do
    it "destroys a personalization option even when used in past orders" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      order = Order.create!(
        customer: Customer.create!(name: "Cliente ord", email: "ord@example.com", password: "password123"),
        status: "pending",
        subtotal_cents: 1000,
        shipping_cents: 500,
        total_cents: 1500,
        shipping_address_snapshot: { street: "Rua Teste", number: "123", city: "São Paulo", state: "SP", zip: "01000-000" },
        idempotency_key: SecureRandom.uuid
      )
      item = OrderItem.create!(order: order, product: product, product_name: product.name, sku: product.sku, unit_price_cents: product.price_cents, quantity: 1, personalizations: [ { label: option.label, value: "Maria" } ])

      expect do
        delete admin_product_personalization_option_path(product, option)
      end.to change(PersonalizationOption, :count).by(-1)

      expect(response).to redirect_to(admin_product_path(product))
      expect(item.reload.personalization_entries.first[:value]).to eq("Maria")
    end
  end
end
