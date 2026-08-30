# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Security headers", type: :request do
  it "sets a strict Content-Security-Policy with a non-empty nonce" do
    get root_path

    csp = response.headers["Content-Security-Policy"]

    expect(csp).to include("default-src 'self'")
    expect(csp).to include("object-src 'none'")

    nonce = csp[/script-src 'self' 'nonce-([^']+)'/, 1]
    expect(nonce).to be_present
  end
end
