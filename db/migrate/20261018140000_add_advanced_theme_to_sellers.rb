class AddAdvancedThemeToSellers < ActiveRecord::Migration[8.1]
  def change
    # Os defaults reproduzem a vitrine atual: nenhum ateliê muda de aparência
    # até o artesão escolher outra coisa.
    add_column :sellers, :theme_sections, :string, array: true, null: false, default: %w[catalog about footer]
    add_column :sellers, :theme_accent_color, :string
    add_column :sellers, :theme_corners, :string, null: false, default: "suaves"
    add_column :sellers, :theme_card_style, :string, null: false, default: "limpo"
    add_column :sellers, :about_text, :string, limit: 1000
    add_column :sellers, :notice_text, :string, limit: 140
    add_column :sellers, :instagram_handle, :string, limit: 30
    add_column :sellers, :whatsapp_number, :string, limit: 13
  end
end
