require "application_system_test_case"

class GoogleAnalyticsConsentTest < ApplicationSystemTestCase
  test "loads analytics only after consent and never on the cart" do
    with_measurement_id do
      visit root_path

      assert_text "Métricas de uso"
      assert_no_selector "script#eloshop-google-analytics", visible: :all

      click_button "Aceitar métricas"

      assert_no_text "Métricas de uso"
      assert_selector "script#eloshop-google-analytics", visible: :all

      visit cart_path

      assert_no_selector "body[data-controller='google-analytics']", visible: :all
      assert_no_selector "script#eloshop-google-analytics", visible: :all

      visit root_path
      assert_selector "script#eloshop-google-analytics", visible: :all
      click_button "Preferências de métricas"
      click_button "Recusar"

      assert_no_selector "script#eloshop-google-analytics", visible: :all
    end
  end

  # No celular as abas inferiores da loja ficam fixas no pé da tela; o aviso
  # precisa ficar acima delas. A regra que o sobe vive fora de `@layer`
  # (application.css): dentro de `components` ela perdia para a utility
  # `bottom-4` do aviso, e o aviso cobria metade das abas. Viewport via CDP
  # porque `resize_to` não desce abaixo de ~500px no Chrome.
  test "on a phone the consent banner sits above the storefront tabs" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)

    with_measurement_id do
      visit root_path
      assert_text "Métricas de uso"

      banner_bottom, tabs_top = page.evaluate_script(<<~JS)
        [document.querySelector("[data-google-analytics-target='banner']").getBoundingClientRect().bottom,
         document.querySelector("nav.storefront-tabs").getBoundingClientRect().top]
      JS

      assert_operator banner_bottom, :<=, tabs_top
    end
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private

  def with_measurement_id
    original = ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"]
    ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"] = "G-ABC123"
    yield
  ensure
    original.nil? ? ENV.delete("GOOGLE_ANALYTICS_MEASUREMENT_ID") : ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"] = original
  end
end
