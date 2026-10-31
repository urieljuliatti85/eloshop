module Admin
  # Histórico de quem mudou o quê (tabela `versions`, PaperTrail). Só leitura.
  class AuditLogsController < BaseController
    TYPES = {
      "Seller" => "Artesão",
      "Product" => "Produto",
      "Coupon" => "Cupom",
      "Order" => "Pedido",
      "SellerOrder" => "Pedido do artesão",
      "PaymentRefund" => "Reembolso"
    }.freeze

    def index
      @type = params[:type] if TYPES.key?(params[:type])

      versions = PaperTrail::Version.order(created_at: :desc, id: :desc)
      versions = versions.where(item_type: @type) if @type
      versions = versions.where(whodunnit: params[:author]) if params[:author].present?

      @versions = paginate(versions)
      @authors = User.where(id: @versions.filter_map(&:whodunnit)).index_by { |user| user.id.to_s }
      @items = @versions.group_by(&:item_type).to_h do |type, group|
        [ type, TYPES.key?(type) ? type.constantize.where(id: group.map(&:item_id)).index_by(&:id) : {} ]
      end
    end
  end
end
