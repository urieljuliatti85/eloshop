module Admin
  class SellersController < BaseController
    before_action :set_seller, only: %i[show approve suspend hide unhide showcase unshowcase]

    def index
      @sellers_in_risk = Seller.approved.where.not(id: Seller.accepted_current_terms_ids).count
      @terms_pending_sellers_count = Seller.where.not(id: Seller.accepted_current_terms_ids).count
      @suspended_sellers_count = Seller.suspended.count

      sellers = Seller.includes(:users, :seller_terms_acceptances).order(created_at: :desc, id: :desc)
      sellers = sellers.where(status: params[:status]) if params[:status].present? && %w[pending approved suspended].include?(params[:status])
      sellers = sellers.where(kind: params[:kind]) if Seller.kinds.key?(params[:kind].to_s)

      case params[:terms].presence
      when "accepted"
        sellers = sellers.where(id: Seller.accepted_current_terms_ids)
      when "pending_terms"
        sellers = sellers.where.not(id: Seller.accepted_current_terms_ids)
      end

      @sellers = paginate(sellers)
    end

    def show
      @products = @seller.products.order(created_at: :desc)
      @fraud_alerts = @seller.fraud_alerts.open.recent_first
      @pending_seller_reports_count = @seller.seller_reports.where(status: %w[pending reviewing]).count
    end

    def approve
      @seller.approve!(kyc_level_6_confirmed: params[:kyc_level_6_confirmed] == "1")
      NotifySellerOfApprovalJob.perform_later(@seller)
      redirect_to admin_seller_path(@seller), notice: "Artesão aprovado."
    rescue Seller::VerificationRequired => e
      redirect_to admin_seller_path(@seller), alert: e.message
    end

    def suspend
      # O mesmo CPF no outro tipo (ateliê/distribuidor) é suspenso junto e
      # recebe o mesmo aviso (ADR 007).
      @seller.suspend!.each do |seller|
        Notification.create!(
          recipient: seller,
          kind: :seller_suspended,
          title: "Conta suspensa",
          body: "Sua conta foi suspensa pela EloShop e a conexão com o Mercado Pago foi desfeita.",
          url: seller_root_path
        )
      end
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

    # Vitrine do pré-cadastro: o ateliê pendente aparece na loja depois da
    # revisão do admin, sem o Mercado Pago, e só passa a vender quando for
    # aprovado. Esconder (`hide`) continua sendo a pausa de quem já aparece.
    def showcase
      @seller.showcase!
      redirect_to admin_seller_path(@seller), notice: "Ateliê liberado na vitrine. Ele aparece na loja, mas só vende depois de aprovado."
    rescue Seller::VerificationRequired => e
      redirect_to admin_seller_path(@seller), alert: e.message
    end

    def unshowcase
      @seller.unshowcase!
      redirect_to admin_seller_path(@seller), notice: "Ateliê retirado da vitrine."
    rescue Seller::VerificationRequired => e
      redirect_to admin_seller_path(@seller), alert: e.message
    end

    private

    def set_seller
      @seller = Seller.find_by!(slug: params[:id])
    end
  end
end
