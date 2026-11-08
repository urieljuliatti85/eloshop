# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin distributor interests", type: :request do
  let!(:interest) do
    DistributorInterest.create!(
      email_address: "lojista@example.com",
      whatsapp_number: "11987654321",
      consent_at: Time.current
    )
  end

  it "blocks visitors who are not logged in" do
    get admin_distributor_interests_path

    expect(response).to redirect_to(new_session_path)
  end

  it "blocks a seller account" do
    seller = Seller.create!(name: "Ateliê", owner_full_name: "Pessoa", cpf: generate_valid_cpf)
    user = User.create!(email_address: "seller-interest@example.com", password: "password123", role: :seller, seller: seller)
    sign_in_as(user)

    get admin_distributor_interests_path

    expect(response).to redirect_to(new_session_path)
  end

  it "lists, marks notified and removes an interest for an admin" do
    admin = User.create!(email_address: "admin-interest@example.com", password: "password123")
    sign_in_as(admin)

    get admin_distributor_interests_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("lojista@example.com", "11987654321")

    patch mark_notified_admin_distributor_interest_path(interest)
    expect(response).to redirect_to(admin_distributor_interests_path)
    expect(interest.reload.notified_at).to be_present

    expect do
      delete admin_distributor_interest_path(interest)
    end.to change(DistributorInterest, :count).by(-1)
  end
end
