require "application_system_test_case"

# O bloco de identidade da sessão de `User` vive dentro do painel do menu
# hambúrguer, que nasce `hidden` — uma auditoria que só visita `/` e mede
# `scrollWidth` nunca chega a renderizá-lo e passa como falso OK. Por isso o
# teste abre o painel antes de medir, e mede também a largura de rolagem do
# próprio painel: um nome de ateliê longo poderia estourar o container sem
# empurrar a página inteira.
#
# `resize_to` não emula viewport estreito de verdade (o Chrome para em
# ~500px) — só o CDP define o viewport real.
class StorefrontHeaderMobileTest < ApplicationSystemTestCase
  MOBILE_WIDTH = 390
  MIN_TOUCH_TARGET = 44

  setup do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: MOBILE_WIDTH, height: 844, deviceScaleFactor: 2, mobile: true)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "announces the admin session in the mobile menu without overflowing" do
    sign_in_as_admin(users(:one))

    visit root_path
    open_mobile_menu

    assert_text "Administrador"
    assert_text users(:one).email_address
    assert_button "Sair"
    # O destino do papel vive só no bloco de identidade: quando também
    # entrava na lista do <nav>, aparecia duas vezes no mesmo painel.
    assert_panel_offers_once "Administração"

    assert_no_horizontal_overflow
    assert_panel_fits
    assert_touch_target_of_link "Administração"
  end

  test "announces the artisan session in the mobile menu without overflowing" do
    user = users(:seller)
    sign_in_as_seller(user)

    visit root_path
    open_mobile_menu

    assert_text "Artesão"
    assert_text user.seller.name
    assert_button "Sair"
    assert_panel_offers_once "Painel do Artesão"

    assert_no_horizontal_overflow
    assert_panel_fits
    assert_touch_target_of_link "Painel do Artesão"
  end

  # O nome do ateliê e o e-mail do admin são dados do usuário, não rótulos
  # fixos: um valor longo não pode empurrar o painel. As classes `truncate` +
  # `min-w-0` é que sustentam isso — sem `min-w-0` um flex item não encolhe
  # abaixo do conteúdo, e o `truncate` não tem efeito.
  test "truncates a long atelier name instead of widening the mobile menu" do
    seller = sellers(:approved)
    seller.update!(name: "Ateliê de Cerâmica Artesanal da Serra da Mantiqueira e Vale do Paraíba")
    sign_in_as_seller(users(:seller))

    visit root_path
    open_mobile_menu

    assert_no_horizontal_overflow
    assert_panel_fits
  end

  private

  def sign_in_as_admin(user)
    visit new_session_path
    fill_in "E-mail", with: user.email_address
    fill_in "Senha", with: "password"
    click_button "Entrar"
    assert_current_path admin_root_path
  end

  def sign_in_as_seller(user)
    visit seller_login_path
    fill_in "E-mail", with: user.email_address
    fill_in "Senha", with: "password"
    click_button "Entrar"
    assert_current_path seller_root_path
  end

  def open_mobile_menu
    find("button[aria-label='Abrir menu']").click
  end

  def assert_no_horizontal_overflow
    scroll_width = page.evaluate_script("document.documentElement.scrollWidth")
    assert_equal MOBILE_WIDTH, scroll_width, "a página estourou a largura do viewport"
  end

  # O painel pode conter conteúdo mais largo que ele mesmo sem vazar para a
  # página — `assert_no_horizontal_overflow` sozinho não pegaria isso.
  def assert_panel_fits
    overflow = page.evaluate_script(<<~JS)
      (() => {
        const panel = document.querySelector("[data-mobile-menu-target='panel']");
        return panel ? panel.scrollWidth - panel.clientWidth : 0;
      })()
    JS

    assert_equal 0, overflow, "o painel do menu tem #{overflow}px de conteúdo fora de alcance"
  end

  def assert_panel_offers_once(label)
    count = page.evaluate_script(<<~JS)
      [...document.querySelectorAll("[data-mobile-menu-target='panel'] a")]
        .filter(a => a.textContent.trim() === #{label.to_json}).length
    JS

    assert_equal 1, count, "\"#{label}\" aparece #{count}x no painel do menu"
  end

  def assert_touch_target_of_link(label)
    height = page.evaluate_script(<<~JS)
      (() => {
        const link = [...document.querySelectorAll("[data-mobile-menu-target='panel'] a")]
          .find(a => a.textContent.trim() === #{label.to_json});
        return link ? Math.round(link.getBoundingClientRect().height) : 0;
      })()
    JS

    assert_operator height, :>=, MIN_TOUCH_TARGET,
      "\"#{label}\" tem #{height}px de altura, abaixo do alvo de toque de #{MIN_TOUCH_TARGET}px"
  end
end
