require "test_helper"

class CategorySeedTest < ActiveSupport::TestCase
  SEED = Rails.root.join("db/seeds/categories.rb")

  setup do
    Category.delete_all
    @casa = Category.create!(name: "Casa")
    @moda = Category.create!(name: "Moda")
    @presentes = Category.create!(name: "Presentes")
  end

  test "adds the new categories under the existing roots and as new roots" do
    load SEED

    assert_equal [ "Iluminação", "Têxteis para casa" ], @casa.children.pluck(:name).sort
    assert_equal [ "Bolsas e carteiras", "Joias e bijuterias", "Roupas" ], @moda.children.pluck(:name).sort
    assert_equal [ "Datas especiais" ], @presentes.children.pluck(:name)
    assert Category.exists?(name: "Infantil", parent_id: nil)
    assert Category.exists?(name: "Papelaria", parent_id: nil)
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
