require "test_helper"

# Sem `config.time_zone`, as telas mostravam UTC: um pedido feito às 12h em
# Brasília aparecia como 15h, e a virada do dia caía às 21h.
class TimeZoneTest < ActiveSupport::TestCase
  test "the application shows Brasília time while the database stays in UTC" do
    assert_equal "Brasilia", Time.zone.name
    assert_equal :utc, ActiveRecord.default_timezone

    instant = Time.utc(2026, 10, 4, 15, 7)

    assert_equal "04/10/2026 às 12:07", I18n.l(instant.in_time_zone, format: :short)
  end

  test "a late-evening order belongs to the local day, not the next UTC day" do
    order_time = Time.utc(2026, 10, 5, 1, 30).in_time_zone

    assert_equal Date.new(2026, 10, 4), order_time.to_date
  end
end
