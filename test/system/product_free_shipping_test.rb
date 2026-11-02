require "application_system_test_case"

# Frete grátis no celular. Em navegador de aplicativo (Instagram, Facebook)
# o window.confirm responde "não" sem aparecer; com o confirm antigo a caixa
# desmarcava sozinha e o ateliê não conseguia oferecer frete grátis. O aviso
# de custo agora é parte da página.
class ProductFreeShippingTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 390, height: 844, deviceScaleFactor: 2, mobile: true)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "free shipping can be checked where confirm() is silent, and the cost notice shows up" do
    user = users(:seller)
    product = user.seller.products.first
    product.update!(free_shipping: false)
    sign_in_seller(user)
    visit edit_seller_product_path(product)

    # Como num navegador de aplicativo: confirm() responde "não" sem aparecer.
    page.execute_script("window.confirm = () => false")

    assert_no_selector "[data-free-shipping-notice]", visible: :visible
    find("label", text: "Frete grátis para este produto").click
    assert find_field("product_free_shipping", visible: :all).checked?
    assert_selector "[data-free-shipping-notice]", visible: :visible, text: "Você assume o custo do envio deste produto"

    # Desmarcar esconde o aviso.
    find("label", text: "Frete grátis para este produto").click
    assert_not find_field("product_free_shipping", visible: :all).checked?
    assert_no_selector "[data-free-shipping-notice]", visible: :visible

    # O botão ao lado faz o mesmo que a caixa, e o texto acompanha o estado.
    click_button "Marcar frete grátis"
    assert find_field("product_free_shipping", visible: :all).checked?
    assert_selector "[data-free-shipping-notice]", visible: :visible
    assert_button "Desmarcar frete grátis"
    click_button "Desmarcar frete grátis"
    assert_not find_field("product_free_shipping", visible: :all).checked?
    assert_no_selector "[data-free-shipping-notice]", visible: :visible
    assert_button "Marcar frete grátis"

    click_button "Marcar frete grátis"
    click_button "Salvar produto"
    assert_text "Produto atualizado com sucesso."
    assert product.reload.free_shipping?
  end

  private

  def sign_in_seller(user)
    visit seller_login_path
    fill_in "E-mail", with: user.email_address
    fill_in "Senha", with: "password"
    click_button "Entrar"
    assert_current_path seller_root_path
  end
end
