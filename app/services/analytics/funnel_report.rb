module Analytics
  class FunnelReport
    REPORT_DAYS = 30
    EVENTS = FunnelEvent::EVENT_NAMES
    Snapshot = Data.define(:period, :counts, :confirmed_revenue_cents, :conversion_rate, :checkout_conversion_rate)

    def snapshot
      rows = FunnelEvent.within(period).group(:event_name).sum(:event_count)
      confirmed_revenue_cents = FunnelEvent.within(period).where(event_name: "order_confirmed").sum(:amount_cents)
      public_visits = rows.fetch("view_catalog", 0) + rows.fetch("view_product", 0)
      confirmed_orders = rows.fetch("order_confirmed", 0)

      Snapshot.new(
        period: period,
        counts: EVENTS.index_with { |event| rows.fetch(event, 0) },
        confirmed_revenue_cents: confirmed_revenue_cents,
        conversion_rate: percentage(confirmed_orders, public_visits),
        checkout_conversion_rate: percentage(confirmed_orders, rows.fetch("checkout_started", 0))
      )
    end

    private

    def period
      (Date.current - (REPORT_DAYS - 1))..Date.current
    end

    def percentage(numerator, denominator)
      return 0.0 if denominator.zero?

      (numerator.to_f / denominator * 100).round(2)
    end
  end
end
