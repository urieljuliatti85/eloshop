require "test_helper"

class PersonalizationOptionTest < ActiveSupport::TestCase
  test "invalid without label" do
    option = PersonalizationOption.new(personalization_options(:name_engraving).attributes.except("id", "label"))
    assert_not option.valid?
    assert_includes option.errors[:label], "can't be blank"
  end

  test "invalid with duplicate label for the same product" do
    duplicate = PersonalizationOption.new(
      product: personalization_options(:name_engraving).product,
      label: personalization_options(:name_engraving).label,
      max_length: 10
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:label], "has already been taken"
  end

  test "the same label can be used by different products" do
    option = PersonalizationOption.new(product: products(:one), label: personalization_options(:name_engraving).label, max_length: 10)
    assert option.valid?
  end

  test "invalid with a non-positive max_length" do
    option = PersonalizationOption.new(product: products(:one), label: "Cor da linha", max_length: 0)
    assert_not option.valid?
    assert_includes option.errors[:max_length], "must be greater than 0"
  end
end
