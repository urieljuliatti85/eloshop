class AddIconTypeToTechniques < ActiveRecord::Migration[8.1]
  def up
    add_column :techniques, :icon_type, :string, null: false, default: "other"
    add_check_constraint :techniques, "icon_type IN ('yarn', 'fabric', 'ribbon', 'notions', 'wood', 'clay', 'needlework', 'knotting', 'paint', 'other')", name: "techniques_icon_type_check"

    execute "UPDATE techniques SET icon_type = 'yarn' WHERE icon_type = 'other' AND (name ILIKE '%crochê%' OR name ILIKE '%croche%')"
    execute "UPDATE techniques SET icon_type = 'needlework' WHERE icon_type = 'other' AND (name ILIKE '%bordado%' OR name ILIKE '%costura%')"
    execute "UPDATE techniques SET icon_type = 'wood' WHERE icon_type = 'other' AND (name ILIKE '%marcenaria%' OR name ILIKE '%entalhe%')"
    execute "UPDATE techniques SET icon_type = 'knotting' WHERE icon_type = 'other' AND (name ILIKE '%macramê%' OR name ILIKE '%macrame%')"
    execute "UPDATE techniques SET icon_type = 'paint' WHERE icon_type = 'other' AND (name ILIKE '%pintura%' OR name ILIKE '%aquarela%')"
    execute "UPDATE techniques SET icon_type = 'clay' WHERE icon_type = 'other' AND (name ILIKE '%cerâmica%' OR name ILIKE '%ceramica%')"
  end

  def down
    remove_check_constraint :techniques, name: "techniques_icon_type_check"
    remove_column :techniques, :icon_type
  end
end
