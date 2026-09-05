# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin admins", type: :request do
  let(:user) { User.create!(email_address: "chefe@eloshop.test", password: "password123") }

  def other_admin(email = "colega-#{SecureRandom.hex(3)}@eloshop.test")
    User.create!(email_address: email, password: "password123")
  end

  describe "GET /admin/admins" do
    it "requires an admin" do
      get admin_admins_path

      expect(response).to redirect_to(new_session_path)
    end

    it "lists the platform admins" do
      colleague = other_admin
      sign_in_as(user)

      get admin_admins_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.email_address)
      expect(response.body).to include(colleague.email_address)
    end

    # O vendedor tem painel próprio e não administra a plataforma.
    it "does not list sellers" do
      seller = Seller.create!(name: "Ateliê #{SecureRandom.hex(3)}", status: :approved, approved_at: Time.current)
      seller_user = User.create!(email_address: "vendedor-lista@eloshop.test", password: "password123", role: :seller, seller: seller)
      sign_in_as(user)

      get admin_admins_path

      expect(response.body).not_to include(seller_user.email_address)
    end
  end

  describe "POST /admin/admins" do
    it "creates another admin" do
      sign_in_as(user)

      expect do
        post admin_admins_path, params: { user: {
          email_address: "novo@eloshop.test", password: "password123", password_confirmation: "password123"
        } }
      end.to change(User.admin, :count).by(1)

      expect(User.find_by(email_address: "novo@eloshop.test")).to be_admin
    end

    it "rejects a mismatched password confirmation" do
      sign_in_as(user)

      post admin_admins_path, params: { user: {
        email_address: "torto@eloshop.test", password: "password123", password_confirmation: "outra"
      } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(User.find_by(email_address: "torto@eloshop.test")).to be_nil
    end
  end

  describe "DELETE /admin/admins/:id" do
    it "removes another admin" do
      colleague = other_admin
      sign_in_as(user)

      expect { delete admin_admin_path(colleague) }.to change(User.admin, :count).by(-1)
    end

    # Removendo a si mesmo, o admin se trancaria para fora no meio da sessão.
    it "refuses to remove your own account" do
      other_admin
      sign_in_as(user)

      expect { delete admin_admin_path(user) }.not_to change(User.admin, :count)
      expect(flash[:alert]).to include("própria conta")
    end

    # Sem admin nenhum, o painel fica inacessível e sem caminho de volta.
    it "refuses to remove the last admin" do
      User.admin.where.not(id: user.id).destroy_all
      sign_in_as(user)
      colleague = other_admin

      delete admin_admin_path(colleague)
      expect(User.admin.count).to eq(1)

      delete admin_admin_path(User.admin.first)
      expect(User.admin.count).to eq(1)
    end
  end
end
