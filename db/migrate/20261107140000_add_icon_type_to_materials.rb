class AddIconTypeToMaterials < ActiveRecord::Migration[8.1]
  def up
    add_column :materials, :icon_type, :string, null: false, default: "other"
    add_check_constraint :materials, "icon_type IN ('yarn', 'fabric', 'ribbon', 'notions', 'wood', 'clay', 'other')", name: "materials_icon_type_check"

    execute <<~SQL
      UPDATE materials SET icon_type = 'yarn'
      WHERE name ILIKE '%fio%' OR name ILIKE '%linha%' OR name ILIKE '%lã%' OR name ILIKE '%algodão%'
    SQL
    execute <<~SQL
      UPDATE materials SET icon_type = 'fabric'
      WHERE icon_type = 'other' AND (name ILIKE '%tecido%' OR name ILIKE '%linho%' OR name ILIKE '%feltro%' OR name ILIKE '%malha%' OR name ILIKE '%manta%')
    SQL
    execute <<~SQL
      UPDATE materials SET icon_type = 'ribbon'
      WHERE icon_type = 'other' AND (name ILIKE '%fita%' OR name ILIKE '%renda%' OR name ILIKE '%galão%' OR name ILIKE '%cetim%' OR name ILIKE '%gorgurão%')
    SQL
    execute <<~SQL
      UPDATE materials SET icon_type = 'notions'
      WHERE icon_type = 'other' AND (name ILIKE '%aviamento%' OR name ILIKE '%botão%' OR name ILIKE '%zíper%' OR name ILIKE '%agulha%' OR name ILIKE '%ferragem%' OR name ILIKE '%miçanga%' OR name ILIKE '%conta%')
    SQL
    execute <<~SQL
      UPDATE materials SET icon_type = 'wood'
      WHERE icon_type = 'other' AND (name ILIKE '%madeira%' OR name ILIKE '%vime%')
    SQL
    execute <<~SQL
      UPDATE materials SET icon_type = 'clay'
      WHERE icon_type = 'other' AND (name ILIKE '%argila%' OR name ILIKE '%cerâmica%')
    SQL
  end

  def down
    remove_check_constraint :materials, name: "materials_icon_type_check"
    remove_column :materials, :icon_type
  end
end
