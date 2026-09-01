require "application_system_test_case"

class WishlistTest < ApplicationSystemTestCase
  test "favoriting a product from the PDP, then moving it to the cart from the wishlist" do
    product = products(:one)
    customer = customers(:one)

    sign_in_as_customer(customer)
    assert_text "Login realizado com sucesso"

    visit product_path(product.seller, product.slug)
    click_button "Adicionar #{product.name} aos favoritos"

    visit wishlist_path
    assert_text product.name

    click_button "Mover para o carrinho"

    assert_current_path cart_path
    assert_text product.name
    assert_equal 0, customer.wishlist_items.count
  end

  private

  def sign_in_as_customer(customer)
    visit new_customer_session_path
    fill_in "E-mail", with: customer.email
    fill_in "Senha", with: "password123"
    click_button "Entrar"
  end
end
