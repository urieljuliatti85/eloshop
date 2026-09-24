module Admin
  class SellersController < BaseController
    before_action :set_seller, only: %i[show approve suspend]

    def index
      all_sellers = Seller.includes(:users, :seller_terms_acceptances).order(created_at: :desc).to_a

      @sellers_in_risk = all_sellers.count { |seller| seller.approved? && !seller.terms_accepted? }
      @terms_pending_sellers_count = all_sellers.count { |seller| !seller.terms_accepted? }
      @suspended_sellers_count = all_sellers.count(&:suspended?)

      @sellers = all_sellers

      if params[:status].present? && %w[pending approved suspended].include?(params[:status])
        @sellers = @sellers.select { |seller| seller.status == params[:status] }
      end

      case params[:terms].presence
      when "accepted"
        @sellers = @sellers.select { |seller| seller.terms_accepted? }
      when "pending_terms"
        @sellers = @sellers.select { |seller| !seller.terms_accepted? }
      else
        @sellers
      end
    end

    def show
      @products = @seller.products.order(created_at: :desc)
    end

    def approve
      @seller.approve!(kyc_level_6_confirmed: params[:kyc_level_6_confirmed] == "1")
      redirect_to admin_seller_path(@seller), notice: "Artesão aprovado."
    rescue Seller::VerificationRequired => e
      redirect_to admin_seller_path(@seller), alert: e.message
    end

    def suspend
      @seller.suspend!
      redirect_to admin_seller_path(@seller), notice: "Artesão suspenso e conta Mercado Pago desconectada."
    end

    private

    def set_seller
      @seller = Seller.find_by!(slug: params[:id])
    end
  end
end
