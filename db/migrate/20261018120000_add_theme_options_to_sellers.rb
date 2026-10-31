class AddThemeOptionsToSellers < ActiveRecord::Migration[8.1]
  def change
    # Os defaults reproduzem a vitrine que já existia, então nenhum ateliê
    # muda de aparência até o artesão escolher outra coisa.
    add_column :sellers, :theme_palette, :string, null: false, default: "terracota"
    add_column :sellers, :theme_font, :string, null: false, default: "moderna"
    add_column :sellers, :theme_layout, :string, null: false, default: "grade"
    add_column :sellers, :theme_hero, :string, null: false, default: "capa"
  end
end
