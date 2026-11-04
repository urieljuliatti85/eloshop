require "test_helper"

class CategorySuggestionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @seller = sellers(:approved)
    @other_seller = sellers(:other)
    @admin = users(:one)
  end

  test "creates a pending suggestion with the seller as requester" do
    result = CategorySuggestion.suggest!(seller: @seller, name: "  Macramê   de parede ")

    assert_equal :created, result.outcome
    assert result.suggestion.pending?
    assert_equal "Macramê de parede", result.suggestion.name
    assert_equal "macrame-de-parede", result.suggestion.normalized_key
    assert_equal [ @seller ], result.suggestion.sellers.to_a
  end

  test "names that differ only in case, accents and spaces become one suggestion" do
    first = CategorySuggestion.suggest!(seller: @seller, name: "Cerâmica Raku")
    second = CategorySuggestion.suggest!(seller: @other_seller, name: "ceramica   raku")

    assert_equal :joined, second.outcome
    assert_equal first.suggestion, second.suggestion
    assert_equal 1, CategorySuggestion.pending.count
    assert_equal [ @seller, @other_seller ].sort_by(&:id), first.suggestion.reload.sellers.sort_by(&:id)
  end

  test "the same seller suggesting twice is told it already did" do
    CategorySuggestion.suggest!(seller: @seller, name: "Cestaria")
    result = CategorySuggestion.suggest!(seller: @seller, name: "CESTARIA")

    assert_equal :already_requested, result.outcome
    assert_equal 1, result.suggestion.requests.count
  end

  # O índice único parcial é quem garante uma sugestão por nome: com uma
  # pendente gravada por outro processo, a criação é recusada pelo banco e a
  # sugestão que venceu é reaproveitada.
  test "a pending suggestion created concurrently is reused through the unique index" do
    winner = CategorySuggestion.create!(name: "Papel machê")

    result = CategorySuggestion.suggest!(seller: @other_seller, name: "Papel Mache")

    assert_equal :joined, result.outcome
    assert_equal winner, result.suggestion
    assert_equal 1, CategorySuggestion.pending.count
  end

  test "the database refuses two pending suggestions with the same key" do
    CategorySuggestion.create!(name: "Bordado livre")

    assert_raises(ActiveRecord::RecordNotUnique) { CategorySuggestion.create!(name: "bordado  LIVRE") }
  end

  test "a name that matches an existing category is refused with that category" do
    parent = Category.create!(name: "Casa")
    existing = Category.create!(name: "Cerâmica", parent: parent)

    result = CategorySuggestion.suggest!(seller: @seller, name: "ceramica")

    assert_equal :category_exists, result.outcome
    assert_equal existing, result.category
    assert_equal 0, CategorySuggestion.count
  end

  test "an inactive category still counts as existing" do
    existing = Category.create!(name: "Velas", active: false)

    result = CategorySuggestion.suggest!(seller: @seller, name: "Velas")

    assert_equal :category_exists, result.outcome
    assert_equal existing, result.category
  end

  test "a renamed category still blocks its old slug" do
    existing = Category.create!(name: "Tapeçaria")
    existing.update!(name: "Tecelagem")

    result = CategorySuggestion.suggest!(seller: @seller, name: "Tapeçaria")

    assert_equal :category_exists, result.outcome
    assert_equal existing, result.category
  end

  test "blank, punctuation-only and too long names are invalid" do
    [ "", "   ", "!!!", "a" * (CategorySuggestion::NAME_MAX_LENGTH + 1) ].each do |name|
      result = CategorySuggestion.suggest!(seller: @seller, name: name)

      assert_equal :invalid, result.outcome, name.inspect
      assert result.suggestion.errors[:name].any?, name.inspect
    end
    assert_equal 0, CategorySuggestion.count
  end

  # "Æ" vira "ae" e "ß" vira "ss" no parameterize: 60 caracteres válidos
  # geravam uma chave de 120 e o banco recusava com ValueTooLong (erro 500).
  test "a name whose key grows past the limit on normalization is invalid, not an error" do
    [ "Æ" * CategorySuggestion::NAME_MAX_LENGTH, "ß" * CategorySuggestion::NAME_MAX_LENGTH ].each do |name|
      result = CategorySuggestion.suggest!(seller: @seller, name: name)

      assert_equal :invalid, result.outcome, name
      assert result.suggestion.errors[:name].any?, name
    end
    assert_equal 0, CategorySuggestion.count
  end

  # Uma categoria sob mãe desabilitada nasce fora da loja, mas o e-mail diz
  # ao ateliê que ela "já está disponível".
  test "accepting under a disabled parent, or under one hidden by its own parent, is refused" do
    disabled = Category.create!(name: "Desligada", active: false)
    hidden = Category.create!(name: "Sob desligada", parent: disabled)

    [ disabled, hidden ].each do |parent|
      suggestion = CategorySuggestion.suggest!(seller: @seller, name: "Pirografia #{parent.id}").suggestion

      assert_no_enqueued_jobs do
        assert_not suggestion.accept!(name: suggestion.name, parent: parent, admin: @admin)
      end
      assert_match "fora da loja", suggestion.errors.full_messages.to_sentence
      assert suggestion.reload.pending?
    end
    assert_equal 0, Category.where("name LIKE 'Pirografia%'").count
  end

  test "accepting creates the category under the chosen parent with the corrected name" do
    parent = Category.create!(name: "Decoração")
    suggestion = CategorySuggestion.suggest!(seller: @seller, name: "macrame").suggestion
    CategorySuggestion.suggest!(seller: @other_seller, name: "Macramê")

    assert_enqueued_jobs 2, only: NotifyCategorySuggestionDecisionJob do
      assert suggestion.accept!(name: " Macramê ", parent: parent, admin: @admin)
    end

    suggestion.reload
    assert suggestion.accepted?
    assert_equal "Macramê", suggestion.category.name
    assert_equal parent, suggestion.category.parent
    assert_equal @admin, suggestion.decided_by_user
    assert_not_nil suggestion.decided_at
    assert_includes Category::Tree.load.categories, suggestion.category
  end

  test "accepting twice creates one category and notifies once" do
    suggestion = CategorySuggestion.suggest!(seller: @seller, name: "Cestaria").suggestion
    suggestion.accept!(name: "Cestaria", parent: nil, admin: @admin)

    assert_no_enqueued_jobs do
      assert_not CategorySuggestion.find(suggestion.id).accept!(name: "Cestaria", parent: nil, admin: @admin)
      assert_not CategorySuggestion.find(suggestion.id).reject!(admin: @admin)
    end
    assert_equal 1, Category.where(name: "Cestaria").count
  end

  test "accepting a name whose slug exists elsewhere in the tree fails without changing anything" do
    moda = Category.create!(name: "Moda")
    accessories = Category.create!(name: "Acessórios", parent: moda)
    home = Category.create!(name: "Casa")
    suggestion = CategorySuggestion.create!(name: "Peças de casa")
    suggestion.requests.create!(seller: @seller)

    assert_no_enqueued_jobs do
      assert_not suggestion.accept!(name: "Acessorios", parent: home, admin: @admin)
    end

    assert_includes suggestion.errors.full_messages.to_sentence, accessories.breadcrumb_name
    assert suggestion.reload.pending?
    assert_equal 1, Category.where(slug: "acessorios").count
  end

  test "rejecting notifies every requester and frees the name for a new suggestion" do
    suggestion = CategorySuggestion.suggest!(seller: @seller, name: "Taxidermia").suggestion
    CategorySuggestion.suggest!(seller: @other_seller, name: "taxidermia")

    assert_enqueued_jobs 2, only: NotifyCategorySuggestionDecisionJob do
      assert suggestion.reject!(admin: @admin)
    end
    assert suggestion.reload.rejected?

    again = CategorySuggestion.suggest!(seller: @seller, name: "Taxidermia")
    assert_equal :created, again.outcome
    assert_not_equal suggestion, again.suggestion
    assert_equal 2, CategorySuggestion.where(normalized_key: "taxidermia").count
  end

  # Apagar a categoria criada (sem produtos) ou remover o admin que decidiu
  # esbarrava na FK e virava erro 500 nas telas do admin.
  test "deleting the accepted category keeps the suggestion history" do
    suggestion = CategorySuggestion.suggest!(seller: @seller, name: "Origami").suggestion
    suggestion.accept!(name: "Origami", parent: nil, admin: @admin)

    assert suggestion.category.destroy
    suggestion.reload
    assert suggestion.accepted?
    assert_nil suggestion.category
  end

  test "removing the admin who decided keeps the decision" do
    admin = User.create!(email_address: "decisor-#{SecureRandom.hex(3)}@example.com", password: "password123", role: :admin)
    suggestion = CategorySuggestion.suggest!(seller: @seller, name: "Vitral").suggestion
    suggestion.reject!(admin: admin)

    assert admin.destroy
    suggestion.reload
    assert suggestion.rejected?
    assert_nil suggestion.decided_by_user
    assert_not_nil suggestion.decided_at
  end

  # Corrida: o ateliê entra na sugestão depois de o admin decidir e de os
  # avisos saírem. O pedido novo precisa se avisar sozinho.
  test "a request that joins a suggestion already decided is notified on its own" do
    suggestion = CategorySuggestion.suggest!(seller: @seller, name: "Cestaria").suggestion
    suggestion.reject!(admin: @admin)
    late = suggestion.requests.create!(seller: @other_seller)

    assert_enqueued_with(job: NotifyCategorySuggestionDecisionJob, args: [ late ]) do
      CategorySuggestion.send(:notify_late_request, suggestion, late)
    end
  end

  test "a request on a pending suggestion, or an old request, is not notified early" do
    suggestion = CategorySuggestion.suggest!(seller: @seller, name: "Cestaria").suggestion
    fresh = suggestion.requests.create!(seller: @other_seller)
    old = CategorySuggestionRequest.find(fresh.id)

    assert_no_enqueued_jobs do
      CategorySuggestion.send(:notify_late_request, suggestion, fresh)
      suggestion.update_columns(status: "rejected")
      CategorySuggestion.send(:notify_late_request, suggestion, old)
    end
  end
end
