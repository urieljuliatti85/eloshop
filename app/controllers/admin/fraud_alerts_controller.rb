module Admin
  class FraudAlertsController < BaseController
    STATUS_FILTERS = %w[open resolved all].freeze

    def index
      @status = STATUS_FILTERS.include?(params[:status]) ? params[:status] : "open"
      @rule = params[:rule] if FraudAlert::RULES.key?(params[:rule])

      alerts = FraudAlert.includes(:seller).recent_first
      alerts = alerts.open if @status == "open"
      alerts = alerts.where.not(resolved_at: nil) if @status == "resolved"
      alerts = alerts.where(rule: @rule) if @rule

      @open_count = FraudAlert.open.count
      @sellers_with_open_alerts = FraudAlert.open.distinct.count(:seller_id)
      @resolved_last_30_days = FraudAlert.where(resolved_at: 30.days.ago..).count
      @open_by_rule = FraudAlert.open.group(:rule).count
      @alerts = paginate(alerts)
    end

    def resolve
      alert = FraudAlert.find(params[:id])
      alert.resolve!
      redirect_back_or_to admin_seller_path(alert.seller), notice: "Alerta marcado como resolvido."
    end
  end
end
