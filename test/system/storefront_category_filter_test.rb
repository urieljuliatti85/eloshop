require "application_system_test_case"

# Filtro de categorias da vitrine: menu "Ver todos" (único controle da faixa de
# categorias) e busca com autocomplete de produtos dentro da categoria
# escolhida. Roda em viewport de celular (CDP: `resize_to` não emula largura
# estreita de verdade), onde o menu expande por baixo e o teclado esconde a
# página.
class StorefrontCategoryFilterTest < ApplicationSystemTestCase
  BROWSER = "[data-controller~='category-flyout']"

  setup do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 390, height: 844, deviceScaleFactor: 2, mobile: true)

    @casa = Category.create!(name: "Casa filtro")
    @cozinha = @casa.children.create!(name: "Cozinha filtro")
    @moda = Category.create!(name: "Moda filtro")
    @roupas = @moda.children.create!(name: "Roupas filtro")
    seller = sellers(:approved)
    @caneca = create_product(seller, "Caneca azulejo", @cozinha)
    @camiseta = create_product(seller, "Camiseta azulejo", @roupas)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "the page opens on the whole catalog and the category strip has only 'Ver todos'" do
    visit products_path

    assert_text @caneca.name
    assert_text @camiseta.name
    within "nav[aria-label='Categorias']" do
      assert_button "Ver todos"
      assert_no_link "Todos", exact: true
      assert_no_button "Casa filtro"
    end
  end

  test "opens 'Ver todos' on click, expands a category and filters by one of its children" do
    visit products_path

    within BROWSER do
      assert_no_selector "[data-account-menu-target='panel']", visible: :visible
      click_button "Ver todos"
      click_button "Casa filtro"
      assert_link "Ver tudo em Casa filtro"
      click_link "Cozinha filtro"
    end

    assert_current_path products_path(category: @cozinha.slug)
    assert_text @caneca.name
    assert_no_text @camiseta.name
  end

  test "'Todos os produtos' clears the category and goes back to the whole catalog" do
    visit products_path(category: @cozinha.slug)
    assert_no_text @camiseta.name

    within(BROWSER) do
      click_button "Ver todos"
      click_link "Todos os produtos"
    end

    assert_current_path products_path
    assert_text @caneca.name
    assert_text @camiseta.name
  end

  test "closes the menu with Escape and when clicking elsewhere" do
    visit products_path
    panel = "#{BROWSER} [data-account-menu-target='panel']"

    click_button "Ver todos"
    assert_selector panel, visible: :visible
    find("body").send_keys(:escape)
    assert_no_selector panel, visible: :visible

    click_button "Ver todos"
    assert_selector panel, visible: :visible
    find("h1").click
    assert_no_selector panel, visible: :visible
  end

  test "suggests products of the picked category while typing and opens one by keyboard" do
    visit products_path

    fill_in "Buscar produtos", with: "azulejo"
    # Sem categoria, as duas peças aparecem.
    assert_selector "#search-suggestions [role='option']", count: 2

    # Escolhendo a categoria no dropdown inicial, só as dela.
    select "Cozinha filtro", from: "Categoria"
    assert_selector "#search-suggestions [role='option']", count: 1
    assert_selector "#search-suggestions", text: @caneca.name
    assert_no_selector "#search-suggestions", text: @camiseta.name

    find_field("Buscar produtos").send_keys(:arrow_down, :enter)

    assert_current_path product_path(@caneca.seller, @caneca.slug)
  end

  test "shows a message when nothing matches and closes the list with Escape" do
    visit products_path

    fill_in "Buscar produtos", with: "inexistente"
    assert_selector "#search-suggestions", text: "Nenhum produto encontrado."

    find_field("Buscar produtos").send_keys(:escape)
    assert_no_selector "#search-suggestions", visible: :visible
  end

  test "Enter without picking a suggestion runs the normal search in the chosen category" do
    visit products_path

    select "Moda filtro", from: "Categoria"
    fill_in "Buscar produtos", with: "azulejo"
    assert_selector "#search-suggestions [role='option']", count: 1
    find_field("Buscar produtos").send_keys(:enter)

    assert_current_path products_path(category: @moda.slug, q: "azulejo")
    assert_text @camiseta.name
    assert_no_text @caneca.name
  end

  test "the filter does not overflow the screen sideways" do
    visit products_path

    assert_equal 390, page.evaluate_script("document.documentElement.scrollWidth")
    click_button "Ver todos"
    click_button "Casa filtro"
    assert_selector "#{BROWSER} a", text: "Cozinha filtro"
    assert_equal 390, page.evaluate_script("document.documentElement.scrollWidth")
  end

  private

  def create_product(seller, name, category)
    Product.create!(seller: seller, name: name, sku: "FILTRO-#{SecureRandom.hex(3)}", price_cents: 4_990,
                    stock_quantity: 3, currency: "BRL", status: :active, category: category)
  end
end
