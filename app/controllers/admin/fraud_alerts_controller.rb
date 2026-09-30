module Admin
  class FraudAlertsController < BaseController
    def resolve
      alert = FraudAlert.find(params[:id])
      alert.resolve!
      redirect_to admin_seller_path(alert.seller), notice: "Alerta marcado como resolvido."
    end
  end
end
