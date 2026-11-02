# frozen_string_literal: true

require "rails_helper"

# Navegação do admin no celular: as áreas do dia a dia são abas no rodapé
# (layouts/_admin_mobile_tabs), com as notificações (o sino do topo é só do
# desktop), e as demais ficam numa faixa no topo (layouts/_admin_nav). As duas
# juntas cobrem a lateral do desktop sem repetir área.
RSpec.describe "Admin mobile navigation", type: :request do
  let(:admin) { User.create!(email_address: "abas-admin@example.com", password: "password123", role: :admin) }

  def page_html
    Nokogiri::HTML(response.body)
  end

  def tabs
    page_html.at_css("nav.admin-tabs")
  end

  def top_areas
    page_html.at_css("header.admin-mobile-header nav.admin-mobile-areas")
  end

  before { sign_in_as(admin) }

  it "shows the day-to-day areas and notifications as bottom tabs" do
    get admin_root_path

    labels = tabs.css(".admin-tabs-list > li").map { |item| item.text.squish }
    expect(labels).to eq([ "Início", "Pedidos", "Artesãos", "Produtos", "Notificações" ])
  end

  it "marks the current area in the bottom tabs" do
    get admin_orders_path

    expect(tabs.css("a[aria-current='page']").map { |link| link.text.squish }).to eq([ "Pedidos" ])
    expect(top_areas.css("a[aria-current='page']")).to be_empty
  end

  it "marks the current area in the top strip" do
    get admin_audit_logs_path

    expect(top_areas.css("a[aria-current='page']").map { |link| link.text.squish }).to eq([ "Auditoria" ])
    expect(tabs.css("a[aria-current='page']")).to be_empty
  end

  it "covers every sidebar area exactly once between the top strip and the bottom tabs" do
    get admin_root_path

    sidebar_paths = page_html.css("aside.admin-sidebar nav a").map { |link| link["href"] }
    tab_paths = tabs.css("a").map { |link| link["href"] } - [ admin_notifications_path ]
    top_paths = top_areas.css("a").map { |link| link["href"] } - [ root_path ]

    expect(sidebar_paths).to include(admin_audit_logs_path, admin_mercado_pago_test_accounts_path)
    expect(tab_paths + top_paths).to match_array(sidebar_paths)
    expect(top_areas.css("a").map { |link| link["href"] }.last).to eq(root_path)
  end

  it "offers sign out in the mobile header" do
    get admin_root_path

    expect(page_html.at_css("header.admin-mobile-header form[action='#{session_path}']")).to be_present
  end

  it "counts only the admin's own unread notifications" do
    other_admin = User.create!(email_address: "outro-abas-admin@example.com", password: "password123", role: :admin)
    2.times { |i| Notification.create!(recipient: admin, kind: :seller_report_received, title: "Denúncia #{i}", body: "Ateliê denunciado.") }
    Notification.create!(recipient: admin, kind: :seller_report_received, title: "Lida", body: "Já vista.", read_at: Time.current)
    Notification.create!(recipient: other_admin, kind: :seller_report_received, title: "Alheia", body: "Não é sua.")

    get admin_root_path

    notifications_tab = tabs.at_css("a[href='#{admin_notifications_path}']")
    expect(notifications_tab.at_css(".admin-tab-count").text).to eq("2")
    expect(notifications_tab.text).to include("(2 não lidas)")
  end

  it "has no badge without unread notifications" do
    get admin_root_path

    expect(tabs.at_css(".admin-tab-count")).to be_nil
  end
end
