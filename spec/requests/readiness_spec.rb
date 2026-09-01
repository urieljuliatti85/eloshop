# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Readiness", type: :request do
  it "reports ready when the primary database accepts queries" do
    get readiness_path

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("status" => "ok")
  end

  it "reports unavailable without exposing database error details" do
    allow(ActiveRecord::Base).to receive(:connection).and_raise(
      ActiveRecord::ConnectionNotEstablished, "postgres://user:secret@host/database"
    )

    get readiness_path

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq("status" => "unavailable")
    expect(response.body).not_to include("secret")
  end
end
