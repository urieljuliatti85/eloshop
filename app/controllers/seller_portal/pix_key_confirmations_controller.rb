module SellerPortal
  # Declaração do vendedor de que a conta do Mercado Pago tem chave PIX. Não
  # prova nada (o MP não deixa consultar); só tira o aviso e fecha a etapa dos
  # primeiros passos. Sempre o `current_seller`, nunca um id da requisição.
  class PixKeyConfirmationsController < BaseController
    # `update_column` porque o marco não deve depender das validações do
    # `Seller` (um cadastro legado inválido não pode impedir a confirmação).
    def create
      current_seller.update_column(:pix_key_confirmed_at, Time.current) if current_seller.pix_key_confirmed_at.nil?
      redirect_back fallback_location: seller_getting_started_path, notice: "Anotado: sua chave PIX está cadastrada."
    end

    def destroy
      current_seller.update_column(:pix_key_confirmed_at, nil)
      redirect_back fallback_location: seller_getting_started_path, notice: "Aviso da chave PIX reativado."
    end
  end
end
