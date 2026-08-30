# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) do
    User.create!(email_address: "admin@example.com", password: "password", password_confirmation: "password")
  end

  describe "GET /session/new" do
    it "renders the login form" do
      get new_session_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /session" do
    it "creates a session with valid credentials" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      expect(response).to redirect_to(root_path)
      expect(response.cookies).to have_key("session_id")
    end

    it "rejects invalid credentials" do
      post session_path, params: { email_address: user.email_address, password: "wrong" }

      expect(response).to redirect_to(new_session_path)
      expect(response.cookies["session_id"]).to be_nil
    end
  end

  describe "DELETE /session" do
    it "logs out the current admin" do
      post session_path, params: { email_address: user.email_address, password: "password" }

      delete session_path

      expect(response).to redirect_to(new_session_path)
      expect(response.cookies["session_id"]).to be_nil
    end
  end
end
