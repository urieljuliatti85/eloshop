module Admin
  class SellersController < BaseController
    before_action :set_seller, only: %i[show approve suspend]

    def index
      @sellers = Seller.includes(:users).order(created_at: :desc)
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
      redirect_to admin_seller_path(@seller), notice: "Artesão suspenso."
    end

    private

    def set_seller
      @seller = Seller.find_by!(slug: params[:id])
    end
  end
end
