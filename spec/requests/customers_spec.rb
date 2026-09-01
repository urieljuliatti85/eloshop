# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Customers", type: :request do
  describe "POST /customers" do
    it "creates a customer, starts a session and associates the current cart" do
      get products_path

      expect do
        post customers_path, params: {
          customer: {
            name: "Nova Cliente",
            email: "nova@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end.to change(Customer, :count).by(1)

      expect(response).to redirect_to(root_path)
      expect(Customer.find_by(email: "nova@example.com")).not_to be_nil
      expect(Cart.order(:created_at).last.customer).to eq(Customer.last)
    end

    it "rejects duplicate emails" do
      existing = Customer.create!(name: "Existente", email: "dup@example.com", password: "password123")

      expect do
        post customers_path, params: {
          customer: {
            name: "Duplicado",
            email: existing.email,
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end.not_to change(Customer, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns a newly registered customer to checkout" do
      seller = Seller.create!(name: "Cadastro Checkout", status: :approved, approved_at: Time.current)
      product = Product.create!(seller: seller, name: "Produto cadastro", sku: "RETURN-SIGNUP", price_cents: 1000, stock_quantity: 1, status: :active)
      post cart_items_path, params: { product_id: product.id, quantity: 1 }
      get new_order_path

      post customers_path, params: {
        customer: {
          name: "Cliente Checkout", email: "signup-checkout@example.com",
          password: "password123", password_confirmation: "password123"
        }
      }

      expect(response).to redirect_to(new_order_path)
    end
  end
end
