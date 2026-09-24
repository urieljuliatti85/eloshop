module Admin
  class SellerReportsController < BaseController
    before_action :set_seller_report, only: %i[review resolve dismiss]

    def index
      @seller_reports = SellerReport.includes(:seller, :customer).order(created_at: :desc)
      @seller_reports = @seller_reports.where(status: params[:status]) if params[:status].present?
      @seller_reports = @seller_reports.where(seller_id: params[:seller_id]) if params[:seller_id].present?
    end

    def review
      @seller_report.review!
      redirect_to admin_seller_reports_path, notice: "Denúncia marcada como em análise."
    end

    def resolve
      @seller_report.resolve!
      redirect_to admin_seller_reports_path, notice: "Denúncia resolvida."
    end

    def dismiss
      @seller_report.dismiss!
      redirect_to admin_seller_reports_path, notice: "Denúncia arquivada."
    end

    private

    def set_seller_report
      @seller_report = SellerReport.find(params[:id])
    end
  end
end
