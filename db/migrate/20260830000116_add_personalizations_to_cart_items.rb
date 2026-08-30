class AddPersonalizationsToCartItems < ActiveRecord::Migration[8.1]
  # SHA256 de "[]" (personalizations vazio) — mesmo valor que o callback do
  # model calcula para um CartItem sem personalização, usado aqui só como
  # default de coluna para as linhas existentes.
  EMPTY_DIGEST = "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945"

  def change
    add_column :cart_items, :personalizations, :jsonb, null: false, default: []
    add_column :cart_items, :personalization_digest, :string, null: false, default: EMPTY_DIGEST

    remove_index :cart_items, name: "index_cart_items_on_cart_product_and_variant"

    add_index :cart_items,
              "cart_id, product_id, COALESCE(product_variant_id, 0), personalization_digest",
              unique: true,
              name: "index_cart_items_on_cart_product_variant_and_personalization"
  end
end
