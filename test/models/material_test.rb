require "test_helper"

class MaterialTest < ActiveSupport::TestCase
  test "infers a supply category icon from material names" do
    assert Material.create!(name: "Fio de algodão").category_icon_yarn?
    assert Material.create!(name: "Tecidos e mantas").category_icon_fabric?
    assert Material.create!(name: "Fitas e rendas").category_icon_ribbon?
    assert Material.create!(name: "Aviamentos e botões").category_icon_notions?
  end

  test "keeps an explicitly selected icon category" do
    material = Material.create!(name: "Algodão", icon_type: :fabric)

    assert material.category_icon_fabric?
  end
end
