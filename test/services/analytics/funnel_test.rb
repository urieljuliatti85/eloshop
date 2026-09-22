require "test_helper"

class Analytics::FunnelTest < ActiveSupport::TestCase
  test "agrega eventos iguais no mesmo dia e dimensão" do
    date = Time.zone.parse("2026-09-22 10:00:00")

    2.times { Analytics::Funnel.track("view_catalog", occurred_at: date) }

    event = FunnelEvent.find_by!(event_name: "view_catalog", occurred_on: date.to_date)
    assert_equal 2, event.event_count
    assert_equal 0, event.amount_cents
  end

  test "mantém dimensões de produto sem dados do cliente" do
    product = products(:one)

    Analytics::Funnel.track("view_product", product: product, seller: product.seller)

    event = FunnelEvent.find_by!(event_name: "view_product", product: product)
    assert_equal product.seller_id, event.seller_id
    assert_nil event.attributes["customer_id"]
  end

  test "rejeita evento fora do contrato" do
    assert_raises Analytics::Funnel::InvalidEvent do
      Analytics::Funnel.track("customer_email")
    end
  end
end
