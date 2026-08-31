require "test_helper"

class Category::TreeTest < ActiveSupport::TestCase
  # Cada teste conta as queries porque a razão de existir da árvore é
  # responder hierarquia sem voltar ao banco — um resultado certo com uma
  # query por nível seria a regressão que ela veio impedir.
  test "answers the hierarchy without going back to the database" do
    casa = Category.create!(name: "Casa da árvore")
    decoracao = casa.children.create!(name: "Decoração da árvore")
    vasos = decoracao.children.create!(name: "Vasos da árvore")

    tree = Category::Tree.load

    assert_no_queries do
      assert_equal "Casa da árvore > Decoração da árvore > Vasos da árvore", tree.breadcrumb_name(vasos)
      assert_equal [ casa.id, decoracao.id, vasos.id ].sort, tree.self_and_descendant_ids(casa).sort
    end
  end

  test "self_and_descendant_ids excludes a sibling subtree" do
    casa = Category.create!(name: "Casa irmã")
    decoracao = casa.children.create!(name: "Decoração irmã")
    moda = Category.create!(name: "Moda irmã")

    ids = Category::Tree.load.self_and_descendant_ids(casa)

    assert_includes ids, decoracao.id
    assert_not_includes ids, moda.id
  end

  test "roots returns only the top-level categories" do
    casa = Category.create!(name: "Casa raiz")
    filha = casa.children.create!(name: "Filha raiz")

    roots = Category::Tree.load.roots

    assert_includes roots, casa
    assert_not_includes roots, filha
  end

  test "breadcrumb_name of a top-level category is its own name" do
    casa = Category.create!(name: "Casa sozinha")

    assert_equal "Casa sozinha", Category::Tree.load.breadcrumb_name(casa)
  end

  private

  def assert_no_queries(&block)
    count = 0
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless payload[:name].to_s.in?(%w[SCHEMA TRANSACTION]) || payload[:cached]
    end
    block.call
    assert_equal 0, count, "esperava nenhuma query, o banco foi consultado #{count}x"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end
end
