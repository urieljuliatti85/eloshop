# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Customer password recovery", type: :request do
  let(:customer) { Customer.create!(name: "Maria", email: "recupera-#{SecureRandom.hex(4)}@example.com", password: "senha-antiga-1") }

  def sign_in_customer
    post customer_session_path, params: { email: customer.email, password: "senha-antiga-1" }
  end

  describe "asking for the link" do
    it "renders the request form and the login page links to it" do
      get new_customer_password_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Esqueceu sua senha?")

      get new_customer_session_path
      expect(response.body).to include(new_customer_password_path)
    end

    it "e-mails the link to an existing customer" do
      expect do
        post customer_passwords_path, params: { email: customer.email }
      end.to have_enqueued_mail(PasswordsMailer, :customer_reset)

      expect(response).to redirect_to(new_customer_session_path)
    end

    it "gives the same answer for an unknown e-mail and sends nothing, so it does not reveal who has an account" do
      post customer_passwords_path, params: { email: customer.email }
      known_notice = flash[:notice]

      expect do
        post customer_passwords_path, params: { email: "ninguem@example.com" }
      end.not_to have_enqueued_mail(PasswordsMailer, :customer_reset)

      expect(response).to redirect_to(new_customer_session_path)
      expect(flash[:notice]).to eq(known_notice)
    end

    it "finds the account regardless of letter case and spaces" do
      expect do
        post customer_passwords_path, params: { email: "  #{customer.email.upcase} " }
      end.to have_enqueued_mail(PasswordsMailer, :customer_reset)
    end

    it "limits repeated requests" do
      5.times { post customer_passwords_path, params: { email: customer.email } }

      post customer_passwords_path, params: { email: customer.email }

      expect(response).to redirect_to(new_customer_password_path)
      expect(flash[:alert]).to eq("Tente novamente mais tarde.")
    end
  end

  describe "choosing a new password" do
    let(:token) { customer.password_reset_token }

    it "shows the form for a valid token" do
      get edit_customer_password_path(token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Crie uma nova senha")
    end

    it "rejects an invalid or forged token" do
      get edit_customer_password_path("token-falso")

      expect(response).to redirect_to(new_customer_password_path)
      expect(flash[:alert]).to include("inválido ou expirou")
    end

    it "does not accept a token that belongs to an admin or seller account" do
      user = User.create!(email_address: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123")

      get edit_customer_password_path(user.password_reset_token)

      expect(response).to redirect_to(new_customer_password_path)
    end

    it "rejects an expired token" do
      expired = travel_to(20.minutes.ago) { customer.password_reset_token }

      get edit_customer_password_path(expired)

      expect(response).to redirect_to(new_customer_password_path)
    end

    it "changes the password, logs the old sessions out and lets the new password in" do
      sign_in_customer
      expect(customer.customer_sessions.count).to eq(1)

      patch customer_password_path(token), params: { password: "senha-nova-2", password_confirmation: "senha-nova-2" }

      expect(response).to redirect_to(new_customer_session_path)
      expect(customer.reload.customer_sessions.count).to eq(0)
      expect(Customer.authenticate_by(email: customer.email, password: "senha-nova-2")).to eq(customer)
      expect(Customer.authenticate_by(email: customer.email, password: "senha-antiga-1")).to be_nil
    end

    it "makes the same link useless after the password changes" do
      patch customer_password_path(token), params: { password: "senha-nova-2", password_confirmation: "senha-nova-2" }

      get edit_customer_password_path(token)

      expect(response).to redirect_to(new_customer_password_path)
    end

    it "does not change anything when the confirmation differs or the password is blank" do
      patch customer_password_path(token), params: { password: "senha-nova-2", password_confirmation: "outra-coisa" }
      expect(flash[:alert]).to eq("As senhas não coincidem.")

      patch customer_password_path(token), params: { password: "", password_confirmation: "" }
      expect(flash[:alert]).to eq("Escolha uma nova senha.")

      expect(Customer.authenticate_by(email: customer.email, password: "senha-antiga-1")).to eq(customer)
    end
  end
end
