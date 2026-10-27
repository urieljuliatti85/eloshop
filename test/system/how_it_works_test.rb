require "application_system_test_case"

# Os carrosséis da aba "Quem vende" (vantagens e etapas) só existem no
# celular e dependem do carousel_controller: só um teste de sistema prova que
# eles navegam.
class HowItWorksTest < ApplicationSystemTestCase
  MOBILE_WIDTH = 390

  # A emulação de celular (CDP) continua valendo no teste seguinte se não
  # for desfeita.
  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "on mobile, the seller steps are a carousel with buttons and dots" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: MOBILE_WIDTH, height: 844, deviceScaleFactor: 2, mobile: true)
    visit how_it_works_path(aba: "vende")

    assert_selector "[aria-label='Ir para o passo 1'][aria-selected='true']"

    click_button "Próximo passo"
    assert_selector "[aria-label='Ir para o passo 2'][aria-selected='true']"

    find("[aria-label='Ir para o passo 6']").click
    assert_selector "[aria-label='Ir para o passo 6'][aria-selected='true']"

    click_button "Passo anterior"
    assert_selector "[aria-label='Ir para o passo 5'][aria-selected='true']"

    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  test "on mobile, the seller benefits are a carousel too" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: MOBILE_WIDTH, height: 844, deviceScaleFactor: 2, mobile: true)
    visit how_it_works_path(aba: "vende")

    assert_selector "[aria-label='Ir para a vantagem 1'][aria-selected='true']"

    click_button "Próxima vantagem"
    assert_selector "[aria-label='Ir para a vantagem 2'][aria-selected='true']"

    find("[aria-label='Ir para a vantagem 4']").click
    assert_selector "[aria-label='Ir para a vantagem 4'][aria-selected='true']"
  end

  test "on desktop, the carousel controls stay hidden" do
    page.driver.browser.manage.window.resize_to(1400, 900)
    visit how_it_works_path(aba: "vende")

    assert_no_button "Próxima vantagem"
    assert_no_button "Próximo passo"
  end
end
