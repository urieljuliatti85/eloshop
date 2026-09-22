# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Customer postal code lookup", type: :request do
  let(:customer) { Customer.create!(name: "Cliente CEP", email: "cep@example.com", password: "password123") }
  let(:address) { PostalCodeLookup::Address.new(street: "Praça da Sé", neighborhood: "Sé", city: "São Paulo", state: "SP") }

  before do
    post customer_session_path, params: { email: customer.email, password: "password123" }
  end

  it "fills an address from a CEP" do
    allow_any_instance_of(PostalCodeLookup).to receive(:call).with("01001-000").and_return(address)

    get address_postal_code_path(cep: "01001-000")

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq(
      "street" => "Praça da Sé", "neighborhood" => "Sé", "city" => "São Paulo", "state" => "SP"
    )
  end

  it "suggests addresses from state city and street" do
    suggestion = PostalCodeLookup::Suggestion.new(
      zip_code: "01310-100", street: "Avenida Paulista", neighborhood: "Bela Vista", city: "São Paulo", state: "SP"
    )
    allow_any_instance_of(PostalCodeLookup).to receive(:search)
      .with(state: "SP", city: "São Paulo", street: "Paulista")
      .and_return([ suggestion ])

    get address_postal_codes_path, params: { state: "SP", city: "São Paulo", street: "Paulista" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).first).to include(
      "zip_code" => "01310-100", "street" => "Avenida Paulista", "neighborhood" => "Bela Vista"
    )
  end

  it "requires an authenticated customer" do
    delete customer_session_path

    get address_postal_codes_path, params: { state: "SP", city: "São Paulo", street: "Paulista" }

    expect(response).to redirect_to(new_customer_session_path)
  end
end
