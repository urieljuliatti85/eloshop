require "application_system_test_case"

# O tour é JavaScript puro sobre a navegação do painel: só um teste de sistema
# prova que ele abre, avança, destaca o link certo e registra a conclusão.
class SellerTourTest < ApplicationSystemTestCase
  MOBILE_WIDTH = 390

  setup do
    @seller = sellers(:approved)
    @user = users(:seller)
  end

  test "opens on the first access, walks through every step and does not come back" do
    @seller.update!(tour_completed_at: nil)
    sign_in_seller(@user)

    assert_selector "[role='dialog']", text: /passo 1 de 4/i
    assert_text "Primeiros passos"

    click_button "Próximo"
    assert_text(/passo 2 de 4/i)
    click_button "Voltar"
    assert_text(/passo 1 de 4/i)

    3.times { click_button "Próximo" }
    assert_text(/passo 4 de 4/i)
    click_button "Concluir"

    assert_no_selector "[role='dialog']"
    assert_tour_completed

    visit seller_root_path
    assert_no_selector "[role='dialog']"
  end

  test "skipping with Esc counts as completed" do
    @seller.update!(tour_completed_at: nil)
    sign_in_seller(@user)
    assert_selector "[role='dialog']"

    find("body").send_keys(:escape)

    assert_no_selector "[role='dialog']"
    assert_tour_completed
  end

  test "does not open on its own for a seller who already completed it, but the button starts it" do
    @seller.update!(tour_completed_at: Time.current)
    sign_in_seller(@user)
    assert_no_selector "[role='dialog']"

    visit seller_getting_started_path
    click_button "Fazer tour pelo painel"

    assert_selector "[role='dialog']", text: /passo 1 de 4/i
  end

  test "the dashboard call starts the tour again after it was completed" do
    @seller.update!(tour_completed_at: Time.current)
    sign_in_seller(@user)
    assert_no_selector "[role='dialog']"

    click_button "Refazer o tour"

    assert_selector "[role='dialog']", text: /passo 1 de 4/i
  end

  test "opens the mobile menu to highlight the links and closes it afterwards" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: MOBILE_WIDTH, height: 844, deviceScaleFactor: 2, mobile: true)
    @seller.update!(tour_completed_at: nil)
    sign_in_seller(@user)

    assert_selector "[role='dialog']", text: /passo 1 de 4/i
    assert_selector "#seller-nav-panel", visible: :visible

    4.times { |i| click_button(i == 3 ? "Concluir" : "Próximo") }

    assert_no_selector "[role='dialog']"
    assert_no_selector "#seller-nav-panel", visible: :visible
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private

  def assert_tour_completed
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    sleep 0.1 until @seller.reload.tour_completed_at || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    assert @seller.tour_completed_at, "o servidor não registrou a conclusão do tour"
  end

  def sign_in_seller(user)
    visit seller_login_path
    fill_in "E-mail", with: user.email_address
    fill_in "Senha", with: "password"
    click_button "Entrar"
    assert_current_path seller_root_path
  end
end
