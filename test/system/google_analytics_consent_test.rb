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

  private

  def with_measurement_id
    original = ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"]
    ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"] = "G-ABC123"
    yield
  ensure
    original.nil? ? ENV.delete("GOOGLE_ANALYTICS_MEASUREMENT_ID") : ENV["GOOGLE_ANALYTICS_MEASUREMENT_ID"] = original
  end
end
