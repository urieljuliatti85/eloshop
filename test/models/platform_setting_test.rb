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
    assert_match "meados de novembro de 2026", PlatformSetting.pre_launch_notice(ready: false)
  end

  test "the database allows a single row" do
    assert_raises(ActiveRecord::StatementInvalid) { PlatformSetting.create!(id: 2) }
  end
end
