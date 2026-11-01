module SellerPortal
  # A escolha do ateliê entre a cotação do provedor conectado e o frete que
  # ele definiu em cada produto (Shipping::Calculator). Escopo de
  # `current_seller`, sem id por parâmetro.
  class ShippingPreferencesController < BaseController
    def update
      preferred = ActiveModel::Type::Boolean.new.cast(params.expect(:provider_quotes_preferred))
      current_seller.update!(provider_quotes_preferred: preferred)

      notice = preferred ? "Seus pedidos passam a cobrar o frete calculado pelo provedor." : "Seus pedidos passam a cobrar o frete que você definiu em cada produto."
      redirect_to seller_atelier_path, notice: notice
    end
  end
end
