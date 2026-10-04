module SellerPortal
  class ToursController < BaseController
    # Sempre o próprio vendedor da sessão (`current_seller`), nunca um id da
    # requisição. Idempotente: concluir de novo não muda a data original.
    # `update_column` porque o marco não deve depender das validações do
    # `Seller` (um cadastro legado inválido não pode impedir o tour de fechar).
    def complete
      current_seller.update_column(:tour_completed_at, Time.current) if current_seller.tour_completed_at.nil?
      head :no_content
    end
  end
end
