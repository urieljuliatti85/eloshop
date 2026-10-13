# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Contacts", type: :request do
  describe "GET /contact" do
    it "renders the contact form" do
      get new_contact_path

      expect(response).to have_http_status(:ok)
    end

    it "has its own title instead of the site default" do
      get new_contact_path

      expect(response.body).to include("<title>Fale com a gente | EloShop</title>")
    end
  end

  describe "POST /contact" do
    let(:token) { travel_to(10.seconds.ago) { ContactMessage.issue_token } }

    it "sends the message and redirects" do
      expect do
        post contact_path, params: {
          contact_message: { name: "Maria", email: "maria@example.com", message: "Olá!" }, form_token: token
        }
      end.to have_enqueued_mail(ContactMailer, :notify).with({ name: "Maria", email: "maria@example.com", subject: nil, message: "Olá!" })

      expect(response).to redirect_to(new_contact_path)
    end

    it "confirms receipt to the visitor once per hour" do
      params = { contact_message: { name: "Maria", email: "maria@example.com", message: "Olá!" }, form_token: token }

      expect { post contact_path, params: params }.to have_enqueued_mail(ContactMailer, :confirmation).with({ email: "maria@example.com" })
      expect { post contact_path, params: params }.not_to have_enqueued_mail(ContactMailer, :confirmation)
    end

    it "ignores a submission that fills the decoy field or has no valid token" do
      bot = { contact_message: { name: "Robertkic", email: "bot@example.com", message: "price?" } }

      expect do
        post contact_path, params: bot.merge(form_token: token, website: "http://spam.example")
        post contact_path, params: bot
      end.not_to have_enqueued_mail(ContactMailer, :notify)
    end

    it "rejects invalid contact data" do
      expect do
        post contact_path, params: { contact_message: { name: "", email: "", message: "" }, form_token: token }
      end.not_to have_enqueued_mail(ContactMailer, :notify)
      expect(ActionMailer::Base.deliveries).to be_empty

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
