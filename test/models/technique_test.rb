require "test_helper"

class TechniqueTest < ActiveSupport::TestCase
  test "infers an icon for each established craft technique" do
    assert Technique.create!(name: "Crochê").category_icon_yarn?
    assert Technique.create!(name: "Bordado").category_icon_needlework?
    assert Technique.create!(name: "Marcenaria").category_icon_wood?
    assert Technique.create!(name: "Macramê").category_icon_knotting?
    assert Technique.create!(name: "Pintura").category_icon_paint?
    assert Technique.create!(name: "Cerâmica").category_icon_clay?
  end
end
