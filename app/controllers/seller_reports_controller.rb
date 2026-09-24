class SellerReportsController < StorefrontController
  before_action :set_seller

  # Sem login, denúncia seria anônima e sem como impedir flood do mesmo
  # visitante contra um ateliê — exige customer autenticado, como reviews.
  rate_limit to: 5, within: 15.minutes, only: :create,
    with: -> { redirect_to seller_path(@seller.slug), alert: "Muitas tentativas. Tente novamente mais tarde." }

  def create
    @seller_report = @seller.seller_reports.new(seller_report_params)
    @seller_report.customer = Current.customer

    if @seller_report.save
      redirect_to seller_path(@seller.slug), notice: "Denúncia enviada. Nossa equipe vai analisar o ateliê."
    else
      redirect_to seller_path(@seller.slug), alert: @seller_report.errors.full_messages.to_sentence
    end
  end

  private

  def set_seller
    @seller = Seller.approved.find_by!(slug: params[:seller_slug])
  end

  def seller_report_params
    params.expect(seller_report: %i[reason details])
  end
end
