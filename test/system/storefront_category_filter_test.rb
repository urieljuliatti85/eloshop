require "application_system_test_case"

# Filtro de categorias da vitrine: dropdown pai > filhas e busca com
# autocomplete de produtos dentro da categoria escolhida. Roda em viewport de
# celular (CDP: `resize_to` não emula largura estreita de verdade), onde o
# painel se ancora na faixa inteira e o teclado esconde a página.
class StorefrontCategoryFilterTest < ApplicationSystemTestCase
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

  test "opens a category dropdown on click, lists its children and filters by one" do
    visit products_path

    within "nav[aria-label='Categorias']" do
      assert_no_link "Cozinha filtro"
      click_button "Casa filtro"
      assert_link "Ver tudo em Casa filtro"
      click_link "Cozinha filtro"
    end

    assert_current_path products_path(category: @cozinha.slug)
    assert_text @caneca.name
    assert_no_text @camiseta.name
  end

  test "closes the dropdown with Escape and when clicking elsewhere" do
    visit products_path
    # O card do produto também mostra o nome da categoria: as checagens ficam
    # restritas à faixa para não confundir link de card com item do dropdown.
    menu = "nav[aria-label='Categorias']"

    within(menu) { click_button "Casa filtro" }
    assert_selector "#{menu} a", text: "Cozinha filtro"

    find("body").send_keys(:escape)
    assert_no_selector "#{menu} a", text: "Cozinha filtro"

    within(menu) { click_button "Moda filtro" }
    assert_selector "#{menu} a", text: "Roupas filtro"
    find("h1").click
    assert_no_selector "#{menu} a", text: "Roupas filtro"
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
    within("nav[aria-label='Categorias']") { click_button "Casa filtro" }
    assert_selector "nav[aria-label='Categorias'] a", text: "Cozinha filtro"
    assert_equal 390, page.evaluate_script("document.documentElement.scrollWidth")
  end

  private

  def create_product(seller, name, category)
    Product.create!(seller: seller, name: name, sku: "FILTRO-#{SecureRandom.hex(3)}", price_cents: 4_990,
                    stock_quantity: 3, currency: "BRL", status: :active, category: category)
  end
end
