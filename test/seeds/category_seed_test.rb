require "test_helper"

class CategorySeedTest < ActiveSupport::TestCase
  SEED = Rails.root.join("db/seeds/categories.rb")

  setup do
    Category.delete_all
    @casa = Category.create!(name: "Casa")
    @moda = Category.create!(name: "Moda")
    @presentes = Category.create!(name: "Presentes")
  end

  test "adds the categories under the existing roots and as new roots" do
    load SEED

    assert_includes @casa.children.pluck(:name), "Iluminação"
    assert_includes @casa.children.pluck(:name), "Organização"
    assert_includes @moda.children.pluck(:name), "Roupas"
    assert_includes @moda.children.pluck(:name), "Calçados e sandálias"
    assert_includes @presentes.children.pluck(:name), "Datas especiais"
    assert_includes @presentes.children.pluck(:name), "Aniversário"
    %w[Infantil Papelaria Pets].each do |root|
      assert Category.exists?(name: root, parent_id: nil), "#{root} deveria ser raiz"
    end
    bem_estar = Category.find_by!(name: "Bem-estar e cuidados", parent_id: nil)
    assert_includes bem_estar.children.pluck(:name), "Velas aromáticas"
    assert_equal [ "Acessórios para pets", "Brinquedos para pets" ], Category.find_by!(name: "Pets").children.pluck(:name).sort
  end

  test "creates the whole tree: every name, with no slug repeated" do
    names = CategorySeed.tree.flat_map { |root, children| [ root, *children ] }
    slugs = names.map(&:parameterize)

    assert_equal slugs.uniq.size, slugs.size, "slug repetido: #{slugs.tally.select { |_, n| n > 1 }.keys.inspect}"

    load SEED

    names.each { |name| assert Category.exists?(name: name), "#{name} não foi criada" }
  end

  test "does not collide with slugs of the categories that production already has" do
    existing = %w[Cozinha Decoração Acessórios]
    new_slugs = CategorySeed.tree.values.flatten.map(&:parameterize)

    assert_empty new_slugs & existing.map(&:parameterize)
  end

  test "is idempotent, as production runs it on every boot" do
    load SEED

    assert_no_difference "Category.count" do
      load SEED
    end
  end

  test "never reactivates, renames or moves a category the admin changed" do
    load SEED
    iluminacao = Category.find_by!(name: "Iluminação")
    iluminacao.update!(active: false)
    roupas = Category.find_by!(name: "Roupas")
    roupas.update!(name: "Vestuário")

    load SEED

    assert_not iluminacao.reload.active?
    assert_equal "Vestuário", roupas.reload.name
    # O slug da renomeada continua "roupas": o seed não recria nem briga com ele.
    assert_equal 1, Category.where(slug: "roupas").count
    assert_not Category.exists?(name: "Roupas", parent: @moda)
  end

  test "skips a category whose slug is taken elsewhere instead of failing" do
    Category.create!(name: "Roupas", parent: @presentes)

    assert_nothing_raised { load SEED }

    assert_not Category.exists?(name: "Roupas", parent: @moda)
    assert_equal 1, Category.where(slug: "roupas").count
    assert Category.exists?(name: "Iluminação", parent: @casa), "the rest of the seed still runs"
  end

  test "leaves unrelated categories and their products untouched" do
    lp = Category.create!(name: "LP")
    vinyl = Category.create!(name: '12"', parent: lp)

    load SEED

    assert_equal [ lp.id, vinyl.id ], Category.where(id: [ lp.id, vinyl.id ]).order(:id).pluck(:id)
    assert_equal lp.id, vinyl.reload.parent_id
  end
end
