module Admin
  class SellersController < BaseController
    before_action :set_seller, only: %i[show approve suspend hide unhide]

    def index
      @sellers_in_risk = Seller.approved.where.not(id: accepted_current_terms_seller_ids).count
      @terms_pending_sellers_count = Seller.where.not(id: accepted_current_terms_seller_ids).count
      @suspended_sellers_count = Seller.suspended.count

      sellers = Seller.includes(:users, :seller_terms_acceptances).order(created_at: :desc)
      sellers = sellers.where(status: params[:status]) if params[:status].present? && %w[pending approved suspended].include?(params[:status])

      case params[:terms].presence
      when "accepted"
        sellers = sellers.where(id: accepted_current_terms_seller_ids)
      when "pending_terms"
        sellers = sellers.where.not(id: accepted_current_terms_seller_ids)
      end

      @sellers = paginate(sellers)
    end

    def show
      @products = @seller.products.order(created_at: :desc)
      @pending_seller_reports_count = @seller.seller_reports.where(status: %w[pending reviewing]).count
    end

    def approve
      @seller.approve!(kyc_level_6_confirmed: params[:kyc_level_6_confirmed] == "1")
      redirect_to admin_seller_path(@seller), notice: "Artesão aprovado."
    rescue Seller::VerificationRequired => e
      redirect_to admin_seller_path(@seller), alert: e.message
    end

    def suspend
      @seller.suspend!
      Notification.create!(
        recipient: @seller,
        kind: :seller_suspended,
        title: "Conta suspensa",
        body: "Sua conta foi suspensa pela EloShop e a conexão com o Mercado Pago foi desfeita.",
        url: seller_root_path
      )
      redirect_to admin_seller_path(@seller), notice: "Artesão suspenso e conta Mercado Pago desconectada."
    end

    def hide
      @seller.hide!
      redirect_to admin_seller_path(@seller), notice: "Ateliê escondido da vitrine pública."
    end

    def unhide
      @seller.unhide!
      redirect_to admin_seller_path(@seller), notice: "Ateliê visível na vitrine pública novamente."
    end

    private

    def set_seller
      @seller = Seller.find_by!(slug: params[:id])
    end

    # Ids de vendedores com uma aceitação registrada para a versão vigente
    # dos termos (`Seller#terms_accepted?` faz a mesma pergunta por vendedor,
    # um a um — aqui em uma query só, para paginar/contar sem N+1).
    def accepted_current_terms_seller_ids
      SellerTermsAcceptance.where(terms_version: SellerTerms.version).select(:seller_id)
    end
  end
end
