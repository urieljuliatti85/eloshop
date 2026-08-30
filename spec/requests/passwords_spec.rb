# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Passwords", type: :request do
  let(:user) do
    User.create!(email_address: "reset@example.com", password: "password", password_confirmation: "password")
  end

  describe "GET /password/new" do
    it "renders the reset form" do
      get new_password_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /password" do
    it "sends reset instructions for a known user" do
      expect do
        post passwords_path, params: { email_address: user.email_address }
      end.to have_enqueued_mail(PasswordsMailer, :reset).with(user)

      expect(response).to redirect_to(new_session_path)
    end

    it "does not send reset instructions for an unknown user" do
      expect do
        post passwords_path, params: { email_address: "missing-user@example.com" }
      end.not_to have_enqueued_mail(PasswordsMailer, :reset)

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "GET /password/:token/edit" do
    it "renders the reset form for a valid token" do
      get edit_password_path(user.password_reset_token)

      expect(response).to have_http_status(:ok)
    end

    it "redirects with an invalid token" do
      get edit_password_path("invalid token")

      expect(response).to redirect_to(new_password_path)
    end
  end

  describe "PUT /password/:token" do
    it "updates the password" do
      expect do
        put password_path(user.password_reset_token), params: { password: "newpassword", password_confirmation: "newpassword" }
      end.to change { user.reload.password_digest }

      expect(response).to redirect_to(new_session_path)
    end

    it "rejects mismatched passwords" do
      token = user.password_reset_token

      expect do
        put password_path(token), params: { password: "no", password_confirmation: "match" }
      end.not_to change { user.reload.password_digest }

      expect(response).to redirect_to(edit_password_path(token))
    end
  end
end
