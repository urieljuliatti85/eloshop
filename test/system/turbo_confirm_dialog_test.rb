require "application_system_test_case"

# Botões com `turbo_confirm` no celular. Em navegador de aplicativo
# (Instagram, Facebook) o window.confirm responde "não" sem aparecer, e o
# botão não fazia nada. A confirmação agora é um <dialog> da página
# (app/javascript/confirm_dialog.js), que vale para todos esses botões.
class TurboConfirmDialogTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 390, height: 844, deviceScaleFactor: 2, mobile: true)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "a turbo_confirm button asks in a page dialog that works where confirm() is silent" do
    user = users(:seller)
    product = user.seller.products.first
    variant = product.product_variants.create!(sku: "CONFIRM-#{SecureRandom.hex(3)}", price_cents: 5_000, stock_quantity: 1, color: "Azul")
    sign_in_seller(user)
    visit seller_product_path(product)

    # Como num navegador de aplicativo: se o window.confirm fosse chamado,
    # responderia "não" sem aparecer, e nada aconteceria.
    page.execute_script("window.confirm = () => false")

    # Cancelar: o dialog some, nada é removido e o foco volta ao botão.
    click_remove_variant(variant)
    within("dialog[data-confirm-dialog][open]") do
      assert_text "Remover esta variante?"
      assert_equal "Cancelar", page.evaluate_script("document.activeElement.textContent")
      click_button "Cancelar"
    end
    assert_no_selector "dialog[data-confirm-dialog]"
    assert ProductVariant.exists?(variant.id)
    assert_equal "Remover", page.evaluate_script("document.activeElement.textContent.trim()")

    # Esc também cancela.
    click_remove_variant(variant)
    find("dialog[data-confirm-dialog][open]").send_keys(:escape)
    assert_no_selector "dialog[data-confirm-dialog]"
    assert ProductVariant.exists?(variant.id)

    # Confirmar: a ação segue como antes.
    click_remove_variant(variant)
    within("dialog[data-confirm-dialog][open]") { click_button "Confirmar" }
    assert_no_text variant.sku
    assert_not ProductVariant.exists?(variant.id)
  end

  private

  def click_remove_variant(variant)
    find("form[action='#{seller_product_product_variant_path(variant.product, variant)}'] button", text: "Remover").click
  end

  def sign_in_seller(user)
    visit seller_login_path
    fill_in "E-mail", with: user.email_address
    fill_in "Senha", with: "password"
    click_button "Entrar"
    assert_current_path seller_root_path
  end
end
