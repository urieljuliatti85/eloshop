module Analytics
  class Funnel
    class InvalidEvent < ArgumentError; end

    def self.track(event_name, product: nil, seller: nil, amount_cents: 0, occurred_at: Time.current)
      new.track(event_name, product: product, seller: seller, amount_cents: amount_cents, occurred_at: occurred_at)
    end

    def track(event_name, product: nil, seller: nil, amount_cents: 0, occurred_at: Time.current)
      raise InvalidEvent, "evento de funil desconhecido" unless FunnelEvent::EVENT_NAMES.include?(event_name.to_s)
      raise ArgumentError, "amount_cents deve ser não negativo" if amount_cents.to_i.negative?

      attributes = {
        event_name: event_name.to_s,
        occurred_on: occurred_at.to_date,
        product_id: product&.id,
        seller_id: seller&.id,
        event_count: 1,
        amount_cents: amount_cents.to_i,
        created_at: occurred_at,
        updated_at: occurred_at
      }

      connection = FunnelEvent.connection
      connection.execute(FunnelEvent.sanitize_sql_array([ <<~SQL.squish, *attributes.values ]))
        INSERT INTO funnel_events
          (event_name, occurred_on, product_id, seller_id, event_count, amount_cents, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (event_name, occurred_on, product_id, seller_id)
        DO UPDATE SET
          event_count = funnel_events.event_count + EXCLUDED.event_count,
          amount_cents = funnel_events.amount_cents + EXCLUDED.amount_cents,
          updated_at = EXCLUDED.updated_at
      SQL
    rescue ActiveRecord::ActiveRecordError => e
      Rails.event.notify("analytics.funnel_track_failed", event_name: event_name.to_s, error_class: e.class.name)
      nil
    end
  end
end
