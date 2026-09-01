class ReadinessController < ActionController::API
  def show
    ActiveRecord::Base.connection.select_value("SELECT 1")
    render json: { status: "ok" }
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
    render json: { status: "unavailable" }, status: :service_unavailable
  end
end
