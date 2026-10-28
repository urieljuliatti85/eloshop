# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin sales opening", type: :request do
  include ActiveJob::TestHelper

  let(:admin) { User.create!(email_address: "sales-admin@example.com", password: "password123") }

  before { PlatformSetting.instance.update!(sales_opened_at: nil) }

  it "redirects unauthenticated users to login" do
    post admin_sales_opening_path

    expect(response).to redirect_to(new_session_path)
    expect(PlatformSetting.sales_open?).to be(false)
  end

  it "does not let a seller open sales" do
    sign_in_as(approved_seller.users.first)

    post admin_sales_opening_path

    expect(PlatformSetting.sales_open?).to be(false)
  end

  it "shows the closed state and the button on the dashboard" do
    sign_in_as(admin)

    get admin_root_path

    expect(response.body).to include("Vendas fechadas (pré-cadastro)", "Abrir vendas")
  end

  it "opens sales once and announces it to approved sellers" do
    sign_in_as(admin)

    expect do
      post admin_sales_opening_path
    end.to have_enqueued_job(AnnounceSalesOpeningJob).exactly(:once)

    expect(response).to redirect_to(admin_root_path)
    expect(PlatformSetting.sales_open?).to be(true)

    expect do
      post admin_sales_opening_path
    end.not_to have_enqueued_job(AnnounceSalesOpeningJob)
    expect(flash[:alert]).to include("já estavam abertas")
  end
end
