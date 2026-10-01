module Analytics
  class FunnelReport
    REPORT_DAYS = 30
    EVENTS = FunnelEvent::BUYER_EVENT_NAMES
    Snapshot = Data.define(:period, :counts, :confirmed_revenue_cents, :conversion_rate, :checkout_conversion_rate)
    SellerConnection = Data.define(:period, :started, :completed, :completion_rate, :sellers_started, :sellers_completed)

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

    # Quantos vendedores clicaram em "Conectar Mercado Pago" e quantos voltaram
    # com a conexão feita, no período. A taxa é de conclusões sobre inícios.
    def seller_connection_snapshot
      scope = FunnelEvent.within(period)
      rows = scope.where(event_name: FunnelEvent::SELLER_EVENT_NAMES).group(:event_name).sum(:event_count)
      started = rows.fetch("seller_mp_connect_started", 0)
      completed = rows.fetch("seller_mp_connect_completed", 0)

      SellerConnection.new(
        period: period,
        started: started,
        completed: completed,
        completion_rate: percentage(completed, started),
        sellers_started: scope.where(event_name: "seller_mp_connect_started").where.not(seller_id: nil).distinct.count(:seller_id),
        sellers_completed: scope.where(event_name: "seller_mp_connect_completed").where.not(seller_id: nil).distinct.count(:seller_id)
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
