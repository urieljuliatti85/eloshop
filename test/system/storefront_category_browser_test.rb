require "application_system_test_case"

# Menu "Ver todos" da vitrine: coluna de categorias de topo e, no desktop, as
# filhas abrindo ao lado, à direita; no celular, expandindo por baixo da
# categoria. Os dois layouts mudam de lugar só pelo viewport, então o teste
# define a largura real por CDP (`resize_to` não emula viewport estreito).
class StorefrontCategoryBrowserTest < ApplicationSystemTestCase
  BROWSER = "[data-controller~='category-flyout']"

  setup do
    @casa = Category.create!(name: "Casa menu")
    @casa.children.create!(name: "Cozinha menu")
    @casa.children.create!(name: "Decoração menu")
    @moda = Category.create!(name: "Moda menu")
    @roupas = @moda.children.create!(name: "Roupas menu")
    Category.create!(name: "Infantil menu")
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "on desktop the children open beside the category column, to the right" do
    viewport(1280, 900)
    visit products_path

    click_button "Ver todos"
    # Abre já mostrando as filhas da primeira categoria com filhas.
    assert_selector "#browse-casa-menu a", text: "Cozinha menu"
    assert_selector "#browse-casa-menu a", text: "Decoração menu"
    assert_no_selector "#browse-moda-menu", visible: :visible

    column_right = rect("#{BROWSER} button[data-root-id='#{@casa.id}']")["right"]
    submenu_left = rect("#browse-casa-menu")["left"]
    assert_operator submenu_left, :>=, column_right, "o submenu deveria abrir à direita da coluna de categorias"
  end

  test "on desktop hovering another category swaps the children shown" do
    viewport(1280, 900)
    visit products_path
    click_button "Ver todos"

    find("#{BROWSER} button[data-root-id='#{@moda.id}']").hover

    assert_selector "#browse-moda-menu a", text: "Roupas menu"
    assert_no_selector "#browse-casa-menu", visible: :visible

    click_link "Roupas menu", match: :first
    assert_current_path products_path(category: @roupas.slug)
  end

  test "on desktop the arrow keys move between categories and into the children" do
    viewport(1280, 900)
    visit products_path
    click_button "Ver todos"

    casa_button = find("#{BROWSER} button[data-root-id='#{@casa.id}']")
    casa_button.send_keys(:arrow_down)
    assert_selector "#browse-moda-menu a", text: "Roupas menu"

    find("#{BROWSER} button[data-root-id='#{@moda.id}']").send_keys(:arrow_right)
    assert_equal "Ver tudo em Moda menu", page.evaluate_script("document.activeElement.textContent.trim()")

    find("body").send_keys(:escape)
    assert_no_selector "#{BROWSER} [data-account-menu-target='panel']", visible: :visible
  end

  test "a category without children is a direct link" do
    viewport(1280, 900)
    visit products_path
    click_button "Ver todos"

    within("#{BROWSER} [data-account-menu-target='panel']") { click_link "Infantil menu" }

    assert_current_path products_path(category: "infantil-menu")
  end

  test "on mobile the children expand below the category and collapse on a second tap" do
    viewport(390, 844)
    visit products_path
    click_button "Ver todos"

    # Nada expandido ao abrir: não há coluna lateral no celular.
    assert_no_selector "#browse-casa-menu", visible: :visible

    find("#{BROWSER} button[data-root-id='#{@casa.id}']").click
    assert_selector "#browse-casa-menu a", text: "Cozinha menu"
    root_bottom = rect("#{BROWSER} button[data-root-id='#{@casa.id}']")["bottom"]
    assert_operator rect("#browse-casa-menu")["top"], :>=, root_bottom - 1, "as filhas deveriam abrir por baixo da categoria"
    assert_equal 390, page.evaluate_script("document.documentElement.scrollWidth")

    find("#{BROWSER} button[data-root-id='#{@casa.id}']").click
    assert_no_selector "#browse-casa-menu", visible: :visible
  end

  test "'Ver todos' has the same size as the 'Buscar' button of the search bar" do
    viewport(1280, 900)
    visit products_path

    buscar = rect("form[role='search'] input[type='submit']")
    ver_todos = rect("#{BROWSER} button[data-account-menu-target='button']")
    assert_in_delta buscar["bottom"] - buscar["top"], ver_todos["bottom"] - ver_todos["top"], 0.5, "altura diferente"

    # No celular o "Buscar" ocupa a linha inteira, e o "Ver todos" também.
    viewport(390, 844)
    visit products_path

    buscar = rect("form[role='search'] input[type='submit']")
    ver_todos = rect("#{BROWSER} button[data-account-menu-target='button']")
    assert_in_delta buscar["right"] - buscar["left"], ver_todos["right"] - ver_todos["left"], 0.5, "largura diferente no celular"
    assert_in_delta buscar["bottom"] - buscar["top"], ver_todos["bottom"] - ver_todos["top"], 0.5, "altura diferente no celular"
  end

  private

  def viewport(width, height)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: width < 640)
  end

  def rect(selector)
    page.evaluate_script("(() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return { left: r.left, right: r.right, top: r.top, bottom: r.bottom } })()")
  end
end
