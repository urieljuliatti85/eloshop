class AddVariantToCartItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :cart_items, :product_variant, foreign_key: true

    remove_index :cart_items, [ :cart_id, :product_id ], unique: true

    # COALESCE trata "sem variante" (NULL) como um valor único e estável, do
    # contrário o Postgres deixaria adicionar o mesmo produto sem variante
    # duas vezes ao carrinho (NULL nunca é igual a NULL numa unique index).
    add_index :cart_items,
              "cart_id, product_id, COALESCE(product_variant_id, 0)",
              unique: true,
              name: "index_cart_items_on_cart_product_and_variant"
  end
end
