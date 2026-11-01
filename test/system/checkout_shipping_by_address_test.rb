require "application_system_test_case"

# A lista de modalidades era montada só para o primeiro endereço com cotação:
# trocar de endereço marcava a modalidade desse primeiro endereço, e o resumo
# seguia mostrando o frete dele. O servidor recotava e cobrava o certo, mas o
# cliente via outro valor até o pagamento. As request specs não pegam: o HTML
# inicial está correto, o erro só aparece ao trocar o endereço na página.
class CheckoutShippingByAddressTest < ApplicationSystemTestCase
  setup do
    sellers(:approved).update!(origin_zip_code: "29018120", origin_street: "Rua do Ateliê", origin_number: "10",
      origin_neighborhood: "Centro", origin_city: "Vitória", origin_state: "ES")
    @product = products(:one)
    @product.update!(fixed_shipping_cents: 2000, fixed_shipping_estimated_days: 5,
      fixed_shipping_interstate_cents: 3500, fixed_shipping_interstate_estimated_days: 9,
      local_pickup_enabled: true)
    @customer = customers(:one)
    @customer.addresses.create!(street: "Rua Vitória", number: "2", neighborhood: "Centro",
      city: "Vitória", state: "ES", zip_code: "29018-120")
  end

  test "switching the address shows that address's shipping options and price" do
    visit product_path(@product.seller, @product.slug)
    click_button "Adicionar ao carrinho"
    assert_current_path cart_path

    sign_in_as_customer(@customer)
    visit new_order_path

    find("label", text: "Rua Vitória, 2").click
    assert_selector "label", text: "Até 5 dias úteis · R$ 20,00"
    assert_no_selector "label", text: "Até 9 dias úteis · R$ 35,00"
    assert_selector "[data-checkout-target='shipping']", text: "R$ 20,00"

    find("label", text: "Rua das Flores, 123").click
    assert_selector "label", text: "Até 9 dias úteis · R$ 35,00"
    assert_no_selector "label", text: "Até 5 dias úteis · R$ 20,00"
    assert_selector "[data-checkout-target='shipping']", text: "R$ 35,00"
    assert_selector "[data-checkout-target='total']", text: "R$ 124,90"

    # Os grupos dos outros endereços ficam desabilitados e não vão no envio.
    click_button "Ir para pagamento"
    assert_text "Finalize o pagamento"
    assert_equal 3500, Order.order(:id).last.shipping_cents
  end

  private

  def sign_in_as_customer(customer)
    visit new_customer_session_path
    fill_in "E-mail", with: customer.email
    fill_in "Senha", with: "password123"
    click_button "Entrar"
    assert_no_current_path new_customer_session_path, wait: 5
  end
end
