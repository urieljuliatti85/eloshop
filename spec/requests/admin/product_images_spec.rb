# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin product images", type: :request do
  let(:user) { User.create!(email_address: "image-admin@example.com", password: "password", password_confirmation: "password") }
  let!(:product) { Product.create!(seller: approved_seller, name: "Vaso galeria", sku: "IMG-ADMIN-001", price_cents: 8_990, stock_quantity: 3, currency: "BRL", status: :active) }

  before do
    product.images.attach(io: StringIO.new("fake image bytes"), filename: "photo.png", content_type: "image/png")
  end

  describe "DELETE /admin/products/:product_id/imagens/:id" do
    it "redirects unauthenticated users" do
      attachment = product.images.attachments.first

      delete admin_product_product_image_path(product, attachment)

      expect(response).to redirect_to(new_session_path)
    end

    it "removes the image" do
      post session_path, params: { email_address: user.email_address, password: "password" }
      attachment = product.images.attachments.first

      expect do
        delete admin_product_product_image_path(product, attachment)
      end.to change { product.images.reload.count }.by(-1)

      expect(response).to redirect_to(admin_product_path(product))
    end
  end
end
