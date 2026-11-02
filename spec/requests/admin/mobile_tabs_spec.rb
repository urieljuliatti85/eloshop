# frozen_string_literal: true

require "rails_helper"

# Abas inferiores do admin no celular (layouts/_admin_mobile_tabs): quatro
# áreas do dia a dia, as notificações (o sino do topo é só do desktop) e um
# "Menu" com a lista completa, que é a mesma da lateral.
RSpec.describe "Admin mobile tabs", type: :request do
  let(:admin) { User.create!(email_address: "abas-admin@example.com", password: "password123", role: :admin) }

  def tabs
    Nokogiri::HTML(response.body).at_css("nav.admin-tabs")
  end

  before { sign_in_as(admin) }

  it "shows the main areas and a menu button" do
    get admin_root_path

    labels = tabs.css(".admin-tabs-list > li").map { |item| item.text.squish }
    expect(labels).to eq([ "Início", "Pedidos", "Artesãos", "Notificações", "Menu" ])
  end

  it "marks the current area" do
    get admin_orders_path

    expect(tabs.css(".admin-tabs-list a[aria-current='page']").map { |link| link.text.squish }).to eq([ "Pedidos" ])
  end

  it "lists every admin area in the menu, the same as the sidebar" do
    get admin_root_path

    page = Nokogiri::HTML(response.body)
    sidebar_paths = page.css("aside.admin-sidebar nav a").map { |link| link["href"] }
    sheet_paths = tabs.css(".admin-tabs-sheet a").map { |link| link["href"] }

    expect(sidebar_paths).to include(admin_audit_logs_path, admin_mercado_pago_test_accounts_path)
    expect(sheet_paths).to include(*sidebar_paths, root_path)
    expect(tabs.at_css(".admin-tabs-sheet form[action='#{session_path}']")).to be_present
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
