require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "invalid without name" do
    category = Category.new
    assert_not category.valid?
    assert_includes category.errors[:name], "can't be blank"
  end

  test "assigns slug from name when slug is blank" do
    category = Category.create!(name: "Decoração")
    assert_equal "decoracao", category.slug
  end

  test "invalid with duplicate name under the same parent" do
    parent = Category.create!(name: "Casa")
    parent.children.create!(name: "Decoração")

    duplicate = Category.new(name: "Decoração", parent: parent)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "different names under different parents do not collide" do
    casa = Category.create!(name: "Casa")
    moda = Category.create!(name: "Moda")
    casa.children.create!(name: "Decoração")

    other = Category.new(name: "Acessórios", parent: moda)
    assert other.valid?
  end

  test "the same name under different parents is rejected due to the global slug uniqueness" do
    casa = Category.create!(name: "Casa")
    moda = Category.create!(name: "Moda")
    casa.children.create!(name: "Acessórios")

    duplicate = Category.new(name: "Acessórios", parent: moda)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "invalid when parent is itself" do
    category = Category.create!(name: "Casa")
    category.parent = category

    assert_not category.valid?
    assert_includes category.errors[:parent], "não pode ser a própria categoria nem uma subcategoria dela"
  end

  test "invalid when parent is a descendant (would create a cycle)" do
    casa = Category.create!(name: "Casa")
    decoracao = casa.children.create!(name: "Decoração")

    casa.parent = decoracao
    assert_not casa.valid?
    assert_includes casa.errors[:parent], "não pode ser a própria categoria nem uma subcategoria dela"
  end

  test "breadcrumb_name joins the hierarchy" do
    casa = Category.create!(name: "Casa")
    decoracao = casa.children.create!(name: "Decoração")
    vasos = decoracao.children.create!(name: "Vasos")

    assert_equal "Casa > Decoração > Vasos", vasos.breadcrumb_name
  end

  test "self_and_descendant_ids includes the category and all nested children" do
    casa = Category.create!(name: "Casa")
    decoracao = casa.children.create!(name: "Decoração")
    vasos = decoracao.children.create!(name: "Vasos")
    moda = Category.create!(name: "Moda")

    ids = casa.self_and_descendant_ids
    assert_includes ids, casa.id
    assert_includes ids, decoracao.id
    assert_includes ids, vasos.id
    assert_not_includes ids, moda.id
  end

  test "cannot destroy a category that still has products" do
    category = Category.create!(name: "Casa")
    products(:one).update!(category: category)

    assert_not category.destroy
    assert_includes category.errors[:base], "Cannot delete record because dependent products exist"
  end

  test "cannot destroy a category that still has children" do
    casa = Category.create!(name: "Casa")
    casa.children.create!(name: "Decoração")

    assert_not casa.destroy
  end

  test "visible? is false when the category itself is disabled" do
    category = Category.create!(name: "Casa oculta", active: false)

    assert_not category.visible?
  end

  test "visible? is false when an ancestor is disabled" do
    casa = Category.create!(name: "Casa desligada", active: false)
    decoracao = casa.children.create!(name: "Decoração herdada", active: true)
    vasos = decoracao.children.create!(name: "Vasos herdados", active: true)

    assert_not decoracao.visible?, "subcategoria de categoria desabilitada deve sumir junto"
    assert_not vasos.visible?, "a regra vale para a subárvore inteira, não só o filho direto"
  end

  test "visible? is true for an active category under active ancestors" do
    casa = Category.create!(name: "Casa ligada")
    decoracao = casa.children.create!(name: "Decoração ligada")

    assert decoracao.visible?
  end

  test "hidden_ids covers disabled categories and their whole subtree" do
    casa = Category.create!(name: "Casa hidden", active: false)
    decoracao = casa.children.create!(name: "Decoração hidden")
    outra = Category.create!(name: "Moda hidden")

    hidden = Category.hidden_ids

    assert_includes hidden, casa.id
    assert_includes hidden, decoracao.id
    assert_not_includes hidden, outra.id
  end
end
