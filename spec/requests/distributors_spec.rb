# frozen_string_literal: true

require "rails_helper"

# Lista pública dos distribuidores de insumos (ADR 007), em /distribuidores,
# com o link "Distribuidores" no menu principal. Mostra só
# `Seller.supply_listed`, nunca ateliê, e fica fora do Google até o
# SEO da vitrine de insumos (Fase 26, PR C2).
RSpec.describe "Distributors", type: :request do
  def distributor(status: :pending, showcased: false, hidden: false, issues_invoices: nil)
    Seller.create!(name: "Fios #{SecureRandom.hex(3)}", owner_full_name: "Dona dos Fios", cpf: generate_valid_cpf,
      kind: "distributor", status: status, approved_at: (Time.current if status == :approved),
      showcased_at: (Time.current if showcased), hidden_at: (Time.current if hidden), issues_invoices: issues_invoices)
  end

  it "lists approved and released distributors, never ateliers, unreleased, hidden or suspended ones" do
    approved = distributor(status: :approved, issues_invoices: true)
    released = distributor(showcased: true)
    unreleased = distributor
    hidden = distributor(status: :approved, hidden: true)
    suspended = distributor(status: :suspended)

    get distributors_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(approved.name, released.name, "Nota fiscal: emite")
    expect(response.body).not_to include(unreleased.name, hidden.name, suspended.name, approved_seller.name)
    expect(response.body).to include('name="robots" content="noindex"')
  end

  it "says the first distributors are coming when there is none" do
    get distributors_path

    expect(response.body).to include("Os primeiros distribuidores chegam em breve", CGI.escapeHTML(how_it_works_path(aba: "vende", grupo: "distribuidor")))
  end

  it "has a Distribuidores link in the main menu, on desktop and in the mobile menu" do
    get root_path

    html = Nokogiri::HTML(response.body)
    desktop = html.css("header nav.lg\\:flex a").map { |a| [ a.text.squish, a["href"] ] }
    mobile = html.css("[data-mobile-menu-target='panel'] nav a").map { |a| [ a.text.squish, a["href"] ] }
    expect(desktop).to include([ "Distribuidores", distributors_path ])
    expect(mobile).to include([ "Distribuidores", distributors_path ])
  end

  it "marks the Distribuidores link on its own page" do
    get distributors_path

    current = Nokogiri::HTML(response.body).css("header nav.lg\\:flex a[aria-current='page']").map { |a| a.text.squish }
    expect(current).to eq([ "Distribuidores" ])
  end
end
