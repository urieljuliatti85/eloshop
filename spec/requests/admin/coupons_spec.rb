# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin coupons", type: :request do
  let(:user) { User.create!(email_address: "coupon-admin@example.com", password: "password", password_confirmation: "password") }
  let!(:coupon) { Coupon.create!(code: "PROMO10", discount_type: "percentage", percentage: 10) }

  describe "GET /admin/coupons" do
    it "redirects unauthenticated users to login" do
      get admin_coupons_path

      expect(response).to redirect_to(new_session_path)
    end

    it "allows authenticated users to list coupons" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      get admin_coupons_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(coupon.code)
    end
  end

  describe "POST /admin/coupons" do
    it "creates a percentage coupon" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        post admin_coupons_path, params: { coupon: { code: "VERAO20", discount_type: "percentage", percentage: 20 } }
      end.to change(Coupon, :count).by(1)

      expect(response).to redirect_to(admin_coupons_path)
    end

    it "creates a fixed coupon" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      post admin_coupons_path, params: { coupon: { code: "FIXO20", discount_type: "fixed", amount: "20,00" } }

      expect(Coupon.find_by!(code: "FIXO20").amount_cents).to eq(2_000)
    end

    it "rejects invalid params" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        post admin_coupons_path, params: { coupon: { code: "", discount_type: "percentage", percentage: 10 } }
      end.not_to change(Coupon, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /admin/coupons/:id" do
    it "updates a coupon" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      patch admin_coupon_path(coupon), params: { coupon: { active: false } }

      expect(response).to redirect_to(admin_coupons_path)
      expect(coupon.reload.active?).to be(false)
    end
  end

  describe "DELETE /admin/coupons/:id" do
    it "destroys a coupon" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect do
        delete admin_coupon_path(coupon)
      end.to change(Coupon, :count).by(-1)

      expect(response).to redirect_to(admin_coupons_path)
    end
  end
end
