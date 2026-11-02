# frozen_string_literal: true

require "rails_helper"

# Listagens do admin que passaram a paginar (Cupons, Denúncias, Notificações).
# Os registros são criados no mesmo instante de propósito: sem `id` como
# desempate na ordenação, o OFFSET da segunda página pode repetir um registro
# da primeira e pular outro.
RSpec.describe "Admin pagination", type: :request do
  let(:admin) { User.create!(email_address: "paginacao-admin@example.com", password: "password123", role: :admin) }
  let(:per_page) { Paginatable::DEFAULT_PER_PAGE }
  let(:created_at) { Time.zone.parse("2026-10-15T12:00:00Z") }

  before { sign_in_as(admin) }

  def collect_pages(path, selector)
    [ 1, 2 ].map do |page|
      get path, params: { page: page }
      expect(response).to have_http_status(:ok)
      Nokogiri::HTML(response.body).css(selector).map { |node| node.text.squish }
    end
  end

  it "paginates coupons without repeating or skipping on ties" do
    codes = (per_page + 1).times.map { |i| Coupon.create!(code: "PAGINA#{i.to_s.rjust(2, '0')}", discount_type: :percentage, percentage: 10, created_at: created_at).code }

    first, second = collect_pages(admin_coupons_path, ".admin-content tbody tr td:first-child")

    expect(first.size).to eq(per_page)
    expect(second.size).to eq(1)
    # Mesmo `created_at` em todos: quem decide a ordem é o `id`, do mais novo
    # para o mais antigo. Sem o desempate, a ordem fica a critério do banco.
    expect(first.first).to include(codes.last)
    expect(second.first).to include(codes.first)
    expect(first.join(" ") + " " + second.join(" ")).to include(*codes)
    expect((first + second).uniq.size).to eq(per_page + 1)
  end

  it "paginates seller reports without repeating or skipping on ties" do
    seller = approved_seller
    (per_page + 1).times do |i|
      customer = Customer.create!(name: "Denunciante #{i}", email: "denuncia-#{i}@example.com", password: "password123")
      SellerReport.create!(customer: customer, seller: seller, reason: SellerReport::REASON_LABELS.keys.first, created_at: created_at)
    end

    first, second = collect_pages(admin_seller_reports_path, ".admin-content tbody tr")

    expect(first.size).to eq(per_page)
    expect(second.size).to eq(1)
    reporters = (first + second).map { |row| row[/Denunciante \d+/] }
    expect(reporters.first).to eq("Denunciante #{per_page}")
    expect(reporters.last).to eq("Denunciante 0")
    expect(reporters.uniq.size).to eq(per_page + 1)
  end

  it "paginates the admin's own notifications without repeating or skipping on ties" do
    other_admin = User.create!(email_address: "outro-paginacao@example.com", password: "password123", role: :admin)
    (per_page + 1).times { |i| Notification.create!(recipient: admin, kind: :new_review, title: "Aviso #{i}", body: "Corpo", created_at: created_at) }
    Notification.create!(recipient: other_admin, kind: :new_review, title: "Aviso alheio", body: "Corpo", created_at: created_at)

    first, second = collect_pages(admin_notifications_path, ".admin-content ul li p.font-semibold")

    expect(first.size).to eq(per_page)
    expect(second.size).to eq(1)
    expect(first.first).to eq("Aviso #{per_page}")
    expect(second.first).to eq("Aviso 0")
    expect((first + second).uniq.size).to eq(per_page + 1)
    expect(first + second).not_to include("Aviso alheio")
  end

  it "repeats the pagination above the list on mobile only, with its own accessible name" do
    (per_page + 1).times { |i| Coupon.create!(code: "TOPO#{i}", discount_type: :percentage, percentage: 10) }

    get admin_coupons_path

    html = Nokogiri::HTML(response.body)
    top = html.at_css("nav[aria-label='Paginação, topo da lista']")
    bottom = html.at_css("nav[aria-label='Paginação']")
    expect(top["class"]).to include("lg:hidden")
    expect(bottom["class"]).not_to include("lg:hidden")
    expect(response.body.index("Paginação, topo da lista")).to be < response.body.index("TOPO")
  end

  it "shows no pagination at all when everything fits in one page" do
    Coupon.create!(code: "UNICO", discount_type: :percentage, percentage: 10)

    get admin_coupons_path

    expect(response.body).not_to include("aria-label=\"Paginação")
  end
end
