module Shipping
  # Avisa no painel cada ateliê que tem produto publicado sem frete definido
  # por ele — publicado antes de o frete passar a ser exigido para publicar e,
  # por isso, ainda cobrado pela tabela interna. Rodado uma vez depois do
  # deploy (`bin/rails shipping:notify_missing`); rodar de novo não duplica o
  # aviso enquanto o anterior não for lido.
  class MissingShippingNotice
    def self.call
      new.call
    end

    # Devolve quantos ateliês foram avisados.
    def call
      counts = Product.active.without_seller_defined_shipping.group(:seller_id).count

      Seller.where(id: counts.keys).find_each.count do |seller|
        next false if seller.notifications.shipping_setup_required.unread.exists?

        Notification.create!(
          recipient: seller,
          kind: :shipping_setup_required,
          title: "Defina o frete dos seus produtos",
          body: body_for(counts.fetch(seller.id)),
          url: Rails.application.routes.url_helpers.seller_products_path
        )
      end
    end

    private

    def body_for(count)
      products = count == 1 ? "1 produto publicado está" : "#{count} produtos publicados estão"
      "#{products} com o frete estimado pela EloShop, que pode não cobrir o custo da sua etiqueta. Defina o valor do frete para o seu estado e, se quiser, para outros estados."
    end
  end
end
