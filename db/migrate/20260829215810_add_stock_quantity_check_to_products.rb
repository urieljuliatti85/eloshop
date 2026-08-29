class AddStockQuantityCheckToProducts < ActiveRecord::Migration[8.1]
  def change
    # Defesa em profundidade contra estoque negativo — não depender
    # exclusivamente da validação Rails (ver CLAUDE.md e docs/inventory.md).
    add_check_constraint :products, "stock_quantity >= 0", name: "products_stock_quantity_check"
  end
end
