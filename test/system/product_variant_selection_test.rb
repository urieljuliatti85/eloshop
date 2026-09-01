require "application_system_test_case"

class ProductVariantSelectionTest < ApplicationSystemTestCase
  test "selecting a variant updates the price and adds the right variant to the cart" do
    product = products(:with_variants)
    large = product_variants(:two)
    large.update!(stock_quantity: 5)

    visit product_path(product.seller, product.slug)

    choose "G"

    assert_text formatted_price(large)
    assert_selector "input[type='submit']:not([disabled])"

    click_button "Adicionar ao carrinho"

    assert_current_path cart_path
    assert_text product.name
    assert_equal large.id, CartItem.order(created_at: :desc).first.product_variant_id
  end

  test "a combination with no stock disables the submit button" do
    product = products(:with_variants)
    product_variants(:one).update!(stock_quantity: 0)
    product_variants(:two).update!(stock_quantity: 5)

    visit product_path(product.seller, product.slug)

    assert_text "Sem estoque para esta combinação"
    assert_selector "input[type='submit'][disabled]"
  end

  private

  def formatted_price(variant)
    ActionController::Base.helpers.number_to_currency(variant.price_cents / 100.0)
  end
end
