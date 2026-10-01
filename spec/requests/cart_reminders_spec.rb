# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cart reminder unsubscribe", type: :request do
  let(:customer) { Customer.create!(name: "Cliente", email: "unsub-#{SecureRandom.hex(4)}@example.com", password: "password123") }
  let(:token) { customer.generate_token_for(:cart_reminder_unsubscribe) }

  it "shows a confirmation on GET without changing anything" do
    get cart_reminder_unsubscribe_path(token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Parar de receber lembretes")
    expect(customer.reload.cart_reminder_emails).to be(true)
  end

  it "turns the reminders off on DELETE and keeps order e-mails untouched" do
    delete cart_reminder_unsubscribe_path(token)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("não receberá mais lembretes de carrinho")
    expect(customer.reload.cart_reminder_emails).to be(false)
  end

  it "says the customer already opted out when the link is opened again" do
    customer.update!(cart_reminder_emails: false)

    get cart_reminder_unsubscribe_path(token)

    expect(response.body).to include("já não recebe lembretes")
  end

  it "rejects a forged or tampered token without touching any customer" do
    delete cart_reminder_unsubscribe_path("token-falso")

    expect(response).to have_http_status(:not_found)
    expect(customer.reload.cart_reminder_emails).to be(true)
  end
end
