module Fraud
  # Varre os vendedores atrás de sinais de irregularidade e abre um `FraudAlert`
  # por vendedor e regra. Só observa: nunca suspende, reembolsa nem avisa o
  # vendedor ou o cliente.
  #
  # Idempotente: rodar duas vezes seguidas não cria segundo alerta nem repete a
  # notificação — só alertas recém-abertos são devolvidos por `call`.
  class SellerScan
    # Prazo de envio depois da confirmação do pagamento. Decisão de negócio
    # (2026-09-30): 7 dias corridos; sob encomenda soma o prazo de produção.
    SHIPPING_GRACE = 7.days

    Finding = Struct.new(:seller, :rule, :detail)

    def initialize(now: Time.current)
      @now = now
    end

    def call
      findings = collect_findings
      created = findings.filter_map { |finding| open_or_refresh(finding) }
      resolve_cleared(findings)
      created
    end

    private

    def collect_findings
      unverified_accounts + self_purchases + unshipped_paid_orders + shipped_without_tracking
    end

    # Conta conectada mas que a aprovação não aceitaria hoje. Vendedor aprovado
    # sem Mercado Pago conectado não entra: não recebe dinheiro, então não há o
    # que proteger (é o caso do ateliê da própria plataforma).
    def unverified_accounts
      Seller.approved.select { |seller| seller.mercado_pago_connected? && !seller.approvable_account? }.map do |seller|
        Finding.new(seller, "unverified_account", {
          "live_mode" => seller.mercado_pago_live_mode,
          "test_account" => seller.mercado_pago_test_account
        })
      end
    end

    # Sinal fraco de propósito: quem fraude usa outro e-mail. Em compensação não
    # dá falso positivo.
    def self_purchases
      owners = User.where.not(seller_id: nil).pluck(:seller_id, :email_address)
                   .group_by { |_, email| email.to_s.downcase }
      return [] if owners.empty?

      orders = Order.confirmed.joins(:customer).where("LOWER(customers.email) IN (?)", owners.keys)
                    .includes(:customer, :seller_orders)

      pairs = orders.flat_map do |order|
        seller_ids = owners.fetch(order.customer.email.downcase).map(&:first)
        order.seller_orders.select { |so| seller_ids.include?(so.seller_id) }.map { |so| [ so.seller_id, order.id ] }
      end

      pairs.group_by(&:first).map do |seller_id, group|
        Finding.new(Seller.find(seller_id), "self_purchase", { "order_ids" => group.map(&:last).uniq.sort })
      end
    end

    def unshipped_paid_orders
      late = SellerOrder.confirmed.joins(:shipment).where(shipments: { status: "pending" })
                        .includes(:order, :seller, order_items: :product)
                        .select { |seller_order| shipping_overdue?(seller_order) }

      group_by_seller(late, "unshipped_paid_order")
    end

    def shipped_without_tracking
      late = SellerOrder.joins(:shipment)
                        .where(shipments: { status: "shipped", tracking_code: [ nil, "" ] })
                        .where(shipments: { shipped_at: ..(@now - SHIPPING_GRACE) })
                        .includes(:seller, :shipment)
                        .reject { |seller_order| seller_order.shipment.local_pickup? }

      group_by_seller(late, "shipped_without_tracking")
    end

    def group_by_seller(seller_orders, rule)
      seller_orders.group_by(&:seller).map do |seller, group|
        Finding.new(seller, rule, { "order_ids" => group.map(&:order_id).uniq.sort })
      end
    end

    def shipping_overdue?(seller_order)
      deadline = confirmed_at(seller_order.order) + SHIPPING_GRACE + production_allowance(seller_order)
      deadline < @now
    end

    def production_allowance(seller_order)
      seller_order.order_items.filter_map { |item| item.product.production_time_max_days }.max.to_i.days
    end

    # O evento registra quando o pagamento confirmou o pedido; pedidos antigos
    # sem evento caem na data de criação.
    def confirmed_at(order)
      order.order_events.where(kind: "order_confirmed").minimum(:created_at) || order.created_at
    end

    def open_or_refresh(finding)
      alert = finding.seller.fraud_alerts.open.find_by(rule: finding.rule)
      if alert
        alert.update!(detail: finding.detail) if alert.detail != finding.detail
        return nil
      end

      finding.seller.fraud_alerts.create!(rule: finding.rule, detail: finding.detail, detected_at: @now)
    rescue ActiveRecord::RecordNotUnique
      nil # outra rodada abriu o mesmo alerta entre a consulta e a gravação
    end

    def resolve_cleared(findings)
      active = findings.to_set { |finding| [ finding.seller.id, finding.rule ] }

      FraudAlert.open.find_each do |alert|
        next unless alert.auto_resolvable?

        alert.resolve! unless active.include?([ alert.seller_id, alert.rule ])
      end
    end
  end
end
