# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Contacts", type: :request do
  describe "GET /contact" do
    it "renders the contact form" do
      get new_contact_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /contact" do
    it "sends the message and redirects" do
      expect do
        post contact_path, params: {
          contact_message: { name: "Maria", email: "maria@example.com", message: "Olá!" }
        }
      end.to have_enqueued_mail(ContactMailer, :notify).with({ name: "Maria", email: "maria@example.com", subject: nil, message: "Olá!" })

      expect(response).to redirect_to(new_contact_path)
    end

    it "rejects invalid contact data" do
      expect do
        post contact_path, params: { contact_message: { name: "", email: "", message: "" } }
      end.not_to have_enqueued_mail(ContactMailer, :notify)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
