require "application_system_test_case"

# O comportamento do editor de tema que só existe no navegador: tema pronto
# marcado, setas das seções, arquivo recusado antes do envio, contador de
# caracteres e a prévia em tela cheia (no celular era inalcançável).
class SellerThemeEditorTest < ApplicationSystemTestCase
  test "marks the applied preset, guards section arrows, images and text limits, and expands the preview" do
    sign_in_seller(users(:seller))
    visit edit_seller_theme_path

    rustico = find("button[data-preset='rustico']")
    rustico.click
    assert_equal "true", rustico["aria-pressed"]
    assert_text "Aplicado"

    click_on "Estilo"
    find("label", text: "Grafite").click
    assert_equal "false", rustico["aria-pressed"], "ajustar a paleta desfaz a marca do tema pronto"

    click_on "Seções"
    first_up = all("[data-direction=up]").first
    assert first_up.disabled?
    all("[data-direction=down]").first.click
    assert all("[data-direction=up]").first.disabled?
    refute all("[data-direction=up]")[1].disabled?

    click_on "Imagens"
    attach_file "seller_logo", file_fixture("not_an_image.txt").to_s, make_visible: true
    assert_text "Formato não aceito. Use PNG, JPEG ou WEBP."

    click_on "Textos"
    fill_in "Faixa de aviso (acima do topo)", with: "Abc"
    assert_selector "#notice_text_count", text: "3/#{Seller::NOTICE_TEXT_MAX_LENGTH}"

    click_on "Salvar tema"
    assert_selector "[role=tabpanel]#panel-imagens", visible: true
    assert_current_path edit_seller_theme_path

    click_on "Ampliar"
    assert_selector "[role=dialog][aria-modal=true]"
    click_on "Fechar"
    assert_no_selector "[role=dialog]"
  end

  test "opens the draft preview on a phone" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 2, mobile: true)
    sign_in_seller(users(:seller))
    visit edit_seller_theme_path

    click_on "Prévia"
    assert_selector "[role=dialog] iframe[title='Pré-visualização da vitrine do ateliê']"
    click_on "Fechar"
    assert_no_selector "[role=dialog]"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
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
