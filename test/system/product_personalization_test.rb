require "application_system_test_case"

class ProductPersonalizationTest < ApplicationSystemTestCase
  test "filling the required personalization field and buying preserves the value all the way to the order" do
    product = products(:with_personalization)
    customer = customers(:one)

    visit product_path(product.seller, product.slug)
    fill_in "Nome gravado", with: "Maria"
    click_button "Adicionar ao carrinho"

    assert_current_path cart_path
    assert_text "Nome gravado: Maria"

    sign_in_as_customer(customer)
    assert_text "Login realizado com sucesso"

    visit cart_path
    click_link "Finalizar compra"
    assert_current_path new_order_path
    click_button "Ir para pagamento"

    assert_text "Nome gravado: Maria"
  end

  test "submitting without the required personalization field does not add the item to the cart" do
    product = products(:with_personalization)

    visit product_path(product.seller, product.slug)
    click_button "Adicionar ao carrinho"

    assert_current_path product_path(product.seller, product.slug)
    assert_no_current_path cart_path
  end

  private

  def sign_in_as_customer(customer)
    visit new_customer_session_path
    fill_in "E-mail", with: customer.email
    fill_in "Senha", with: "password123"
    click_button "Entrar"
  end
end
