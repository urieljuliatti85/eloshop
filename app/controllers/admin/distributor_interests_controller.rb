module Admin
  class DistributorInterestsController < BaseController
    def index
      @interests = DistributorInterest.order(created_at: :desc)
      @awaiting_notice_count = @interests.awaiting_notice.count
    end

    def mark_notified
      DistributorInterest.find(params[:id]).update!(notified_at: Time.current)
      redirect_to admin_distributor_interests_path, notice: "Contato marcado como avisado."
    end

    def destroy
      DistributorInterest.find(params[:id]).destroy!
      redirect_to admin_distributor_interests_path, notice: "Interesse removido."
    end
  end
end
