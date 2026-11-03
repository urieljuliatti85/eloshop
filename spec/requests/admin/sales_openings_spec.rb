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

  it "counts on the dashboard who the opening will notify" do
    approved_before = Seller.publicly_listed.approved.count
    showcased_before = Seller.publicly_listed.pending.count
    2.times { create_seller(status: :approved, approved_at: Time.current) }
    2.times { create_seller(status: :pending, showcased_at: Time.current) }
    create_seller(status: :pending)
    create_seller(status: :approved, approved_at: Time.current, hidden_at: Time.current)
    create_seller(status: :suspended)
    sign_in_as(admin)

    get admin_root_path

    expect(response.body).to include(
      "Serão avisados: #{approved_before + 2} ateliês aprovados e #{showcased_before + 2} na vitrine."
    )
  end

  it "does not show the audience once sales are open" do
    PlatformSetting.instance.update!(sales_opened_at: Time.current)
    sign_in_as(admin)

    get admin_root_path

    expect(response.body).not_to include("Serão avisados")
  end

  it "opens sales once and announces it to approved sellers" do
    sign_in_as(admin)

    expect do
      post admin_sales_opening_path
    end.to have_enqueued_job(AnnounceSalesOpeningJob).exactly(:once)

    expect(response).to redirect_to(admin_root_path)
    expect(flash[:notice]).to eq("Vendas abertas. Os ateliês aprovados e os da vitrine vão receber o aviso por e-mail.")
    expect(PlatformSetting.sales_open?).to be(true)

    expect do
      post admin_sales_opening_path
    end.not_to have_enqueued_job(AnnounceSalesOpeningJob)
    expect(flash[:alert]).to include("já estavam abertas")
  end

  def create_seller(**attributes)
    Seller.create!(
      name: "Ateliê Público #{SecureRandom.hex(4)}",
      owner_full_name: "Proprietário Spec",
      cpf: generate_valid_cpf,
      **attributes
    )
  end
end
