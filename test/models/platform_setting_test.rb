require "test_helper"

class PlatformSettingTest < ActiveSupport::TestCase
  test "sales are closed until opened" do
    PlatformSetting.instance.update!(sales_opened_at: nil)

    assert_not PlatformSetting.sales_open?
  end

  test "sales are closed when the row does not exist yet" do
    PlatformSetting.delete_all

    assert_not PlatformSetting.sales_open?
    assert_nil PlatformSetting.sales_opened_at
  end

  test "opens sales once and keeps the first opening date" do
    PlatformSetting.instance.update!(sales_opened_at: nil)

    travel_to Time.zone.local(2026, 11, 15, 9) do
      assert PlatformSetting.open_sales!
    end
    travel_to Time.zone.local(2026, 11, 20, 9) do
      assert_not PlatformSetting.open_sales!
    end

    assert PlatformSetting.sales_open?
    assert_equal Time.zone.local(2026, 11, 15, 9), PlatformSetting.sales_opened_at
  end

  test "the pre-launch notice says ready only when every step is done" do
    assert_match "Sua loja está pronta.", PlatformSetting.pre_launch_notice(ready: true)
    assert_match "Sua loja está quase pronta", PlatformSetting.pre_launch_notice(ready: false)
    assert_match "As vendas abrem em breve e avisaremos por e-mail.", PlatformSetting.pre_launch_notice(ready: false)
  end

  # Painel e e-mail usam a mesma frase; a SuperFrete entra onde a etapa existe.
  test "the almost-ready notice names SuperFrete only while remote quotes are enabled" do
    assert_match "integre com o Mercado Pago e a SuperFrete", PlatformSetting.pre_launch_notice(ready: false)

    previous = Rails.configuration.x.shipping.remote_quotes_enabled
    Rails.configuration.x.shipping.remote_quotes_enabled = false
    assert_no_match "SuperFrete", PlatformSetting.pre_launch_notice(ready: false)
    assert_equal "Siga os passos, integre com o Mercado Pago e adicione produtos.", PlatformSetting.pre_launch_steps_hint
  ensure
    Rails.configuration.x.shipping.remote_quotes_enabled = previous
  end

  test "the database allows a single row" do
    assert_raises(ActiveRecord::StatementInvalid) { PlatformSetting.create!(id: 2) }
  end
end
