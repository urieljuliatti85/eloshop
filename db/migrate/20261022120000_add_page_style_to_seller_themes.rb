class AddPageStyleToSellerThemes < ActiveRecord::Migration[8.1]
  def change
    # Os defaults reproduzem a vitrine atual: nenhum ateliê muda de aparência
    # até o artesão escolher outra coisa.
    add_column :sellers, :theme_background, :string, null: false, default: "branco"
    add_column :sellers, :theme_ornament, :string, null: false, default: "nenhum"
    add_column :sellers, :theme_image_ratio, :string, null: false, default: "quadrada"
    add_column :sellers, :theme_heading_font, :string, null: false, default: "igual"
  end
end
