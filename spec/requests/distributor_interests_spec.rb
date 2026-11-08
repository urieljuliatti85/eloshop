# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Distributor preregistration", type: :request do
  def aged_token
    travel_to(10.seconds.ago) { ContactMessage.issue_token }
  end

  def valid_params(email: "distribuidor@example.com", phone: "(11) 98765-4321", consent: "1")
    {
      distributor_interest: { email_address: email, whatsapp_number: phone },
      consent: consent,
      form_token: aged_token
    }
  end

  def with_turnstile(result)
    allow(Turnstile).to receive(:verify).and_return(result)
  end

  before { with_turnstile(:ok) }

  it "renders the public form at /pre-cadastro/armarinhos" do
    get new_distributor_interest_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Quer ser um distribuidor?")
  end

  it "creates an interest and queues the notification and confirmation" do
    expect do
      post distributor_interest_path, params: valid_params
    end.to change(DistributorInterest, :count).by(1)
      .and have_enqueued_mail(ContactMailer, :distributor_interest)
      .and have_enqueued_mail(ContactMailer, :distributor_interest_confirmation)

    expect(response).to redirect_to(new_distributor_interest_path)
  end

  it "accepts honeypot submissions without storing or mailing" do
    expect do
      post distributor_interest_path, params: valid_params.merge(website: "bot")
    end.not_to change(DistributorInterest, :count)

    expect(response).to redirect_to(new_distributor_interest_path)
    expect(enqueued_jobs).to be_empty
  end

  it "rejects an invalid form token" do
    post distributor_interest_path, params: valid_params.merge(form_token: "forjado")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(DistributorInterest.count).to eq(0)
    expect(enqueued_jobs).to be_empty
  end

  it "requires consent" do
    post distributor_interest_path, params: valid_params(consent: nil)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Autorize o contato para continuar")
    expect(DistributorInterest.count).to eq(0)
    expect(enqueued_jobs).to be_empty
  end

  it "updates a repeated e-mail without sending duplicate messages" do
    post distributor_interest_path, params: valid_params
    clear_enqueued_jobs

    expect do
      post distributor_interest_path, params: valid_params(email: " DISTRIBUIDOR@example.com ", phone: "(21) 91234-5678")
    end.not_to change(DistributorInterest, :count)

    expect(DistributorInterest.first.whatsapp_number).to eq("21912345678")
    expect(enqueued_jobs).to be_empty
  end

  it "rate limits repeated submissions" do
    5.times do |index|
      post distributor_interest_path, params: valid_params(email: "distribuidor#{index}@example.com")
    end

    post distributor_interest_path, params: valid_params(email: "ultimo@example.com")

    expect(response).to redirect_to(new_distributor_interest_path)
    expect(flash[:alert]).to include("Muitas tentativas")
    expect(DistributorInterest.count).to eq(5)
  end
end
