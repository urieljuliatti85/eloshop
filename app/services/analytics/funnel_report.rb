module Analytics
  class FunnelReport
    REPORT_DAYS = 30
    EVENTS = FunnelEvent::BUYER_EVENT_NAMES
    Snapshot = Data.define(:period, :counts, :confirmed_revenue_cents, :conversion_rate, :checkout_conversion_rate)
    SellerConnection = Data.define(:period, :started, :completed, :failed, :completion_rate, :started_by, :completed_by, :failed_by)
    # Um ateliê num dos três grupos: quantas vezes e quando foi a última.
    SellerCount = Data.define(:seller, :count, :last_on)

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

    # Quem clicou em "Conectar Mercado Pago", quem voltou com a conexão feita e
    # quem voltou com falha, no período. A taxa é de conclusões sobre cliques.
    def seller_connection_snapshot
      scope = FunnelEvent.within(period)
      started_by = sellers_for(scope, "seller_mp_connect_started")
      completed_by = sellers_for(scope, "seller_mp_connect_completed")
      failed_by = sellers_for(scope, "seller_mp_connect_failed")
      started = started_by.sum(&:count)
      completed = completed_by.sum(&:count)

      SellerConnection.new(
        period: period,
        started: started,
        completed: completed,
        failed: failed_by.sum(&:count),
        completion_rate: percentage(completed, started),
        started_by: started_by,
        completed_by: completed_by,
        failed_by: failed_by
      )
    end

    private

    def period
      (Date.current - (REPORT_DAYS - 1))..Date.current
    end

    def sellers_for(scope, event_name)
      rows = scope.where(event_name: event_name).where.not(seller_id: nil)
        .group(:seller_id).pluck(:seller_id, Arel.sql("SUM(event_count)"), Arel.sql("MAX(occurred_on)"))
      sellers = Seller.where(id: rows.map(&:first)).includes(:users).index_by(&:id)

      rows.filter_map { |id, count, last_on| (seller = sellers[id]) && SellerCount.new(seller: seller, count: count.to_i, last_on: last_on) }
        .sort_by { |entry| [ -entry.last_on.to_time.to_i, entry.seller.name ] }
    end

    def percentage(numerator, denominator)
      return 0.0 if denominator.zero?

      (numerator.to_f / denominator * 100).round(2)
    end
  end
end
