require "application_system_test_case"

# Abaixo de `lg` as tabelas do admin viram lista de cartões: a primeira
# coluna com nome é o título e as outras aparecem como "rótulo: valor", com o
# rótulo copiado do <thead> pelo table-labels controller. Antes, a tabela
# larga (Pedidos tem 10 colunas) era cortada no celular. Viewport real via
# CDP: `resize_to` não desce abaixo de ~500px.
class AdminMobileListingsTest < ApplicationSystemTestCase
  MOBILE_WIDTH = 375

  setup do
    visit new_session_path
    fill_in "E-mail", with: users(:one).email_address
    fill_in "Senha", with: "password"
    click_button "Entrar"
    assert_current_path admin_root_path

    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: MOBILE_WIDTH, height: 667, deviceScaleFactor: 2, mobile: true)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "shows orders as labeled cards without horizontal scroll" do
    order = orders(:one)

    visit admin_orders_path

    row = find(".admin-content tbody tr", text: "##{order.id}")
    assert_equal "##{order.id}", row.find("td[data-primary]").text
    labels = row.all("td[data-label]").map { |cell| cell[:"data-label"] }
    assert_includes labels, "Cliente"
    assert_includes labels, "Status"
    assert_includes labels, "Total"
    assert_not_includes labels, "Ações", "colunas sem nome (ações) não ganham rótulo"
    assert_no_horizontal_overflow

    row.click_link "Detalhes"
    assert_current_path admin_order_path(order)
  end

  test "fits long badges in the sellers cards" do
    visit admin_sellers_path

    assert_selector ".admin-content td[data-label='Etapa']"
    assert_no_horizontal_overflow
    overflowing = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.admin-content tbody td')].filter((td) => td.scrollWidth > td.clientWidth + 1).length
    JS
    assert_equal 0, overflowing
  end

  # Texto sem espaço (e-mail, código) no título do cartão estourava a célula:
  # só as células com rótulo quebravam em qualquer ponto.
  test "breaks long unspaced text in the card title" do
    Customer.create!(name: "Cliente#{'x' * 80}", email: "longo@example.com", password: "password123")

    visit admin_customers_path

    assert_no_horizontal_overflow
    assert_equal 0, overflowing_cells
  end

  # Os cards de cadastros recentes do dashboard são itens de grid: sem
  # `min-w-0`, o `truncate` (nowrap) fazia o nome inteiro virar a largura
  # mínima do card, e um nome comum já empurrava a página além da tela.
  test "fits recent signups with ordinary long names on the dashboard" do
    Customer.create!(name: "Maria Aparecida dos Santos Oliveira", email: "maria.aparecida.dos.santos.artesanato@hotmail.com", password: "password123")

    visit admin_root_path

    assert_text "Maria Aparecida dos Santos Oliveira"
    assert_no_horizontal_overflow
  end

  private

  def overflowing_cells
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.admin-content tbody td')].filter((td) => td.scrollWidth > td.clientWidth + 1).length
    JS
  end

  def assert_no_horizontal_overflow
    assert_equal MOBILE_WIDTH, page.evaluate_script("document.documentElement.scrollWidth")
  end
end
