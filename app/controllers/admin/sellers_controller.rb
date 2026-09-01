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
      @seller.approve!
      redirect_to admin_seller_path(@seller), notice: "Artesão aprovado."
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
