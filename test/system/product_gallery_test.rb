require "application_system_test_case"

class ProductGalleryTest < ApplicationSystemTestCase
  test "clicking a thumbnail swaps the main image" do
    product = products(:one)
    product.main_image.attach(io: File.open(file_fixture("sample.png")), filename: "cover.png", content_type: "image/png")
    product.images.attach(io: File.open(file_fixture("sample.png")), filename: "extra.png", content_type: "image/png")

    visit product_path(product.seller, product.slug)

    main_image = find("[data-gallery-target='main']")
    initial_src = main_image[:src]

    all("button[data-action='gallery#show']").last.click

    assert_not_equal initial_src, find("[data-gallery-target='main']")[:src]
  end

  # A ampliação abre a foto que está à vista (não a primeira), fecha por Esc,
  # botão e fundo, devolve o foco e não volta aberta pelo "voltar" do Turbo.
  test "the main photo opens enlarged, showing the photo currently in view" do
    product = products(:one)
    product.main_image.attach(io: File.open(file_fixture("sample.png")), filename: "cover.png", content_type: "image/png")
    product.images.attach(io: File.open(file_fixture("sample.png")), filename: "extra.png", content_type: "image/png")

    visit product_path(product.seller, product.slug)
    assert_no_selector "dialog[open]"

    all("button[data-action='gallery#show']").last.click
    main_src = find("[data-gallery-target='main']")[:src]

    click_button "Ampliar foto"
    within "dialog[open]" do
      zoom = find("img[data-gallery-target='zoom']")
      assert_equal main_src, zoom[:src]
      assert_equal "#{product.name} — foto 2 de 2", zoom[:alt]
    end
    assert_selector "html.overflow-hidden"

    # Esc fecha e devolve o foco ao botão que abriu.
    find("dialog[open]").send_keys(:escape)
    assert_no_selector "dialog[open]"
    assert_equal "Ampliar foto", page.evaluate_script("document.activeElement.getAttribute('aria-label')")
    # O evento close do dialog é assíncrono: espera o fundo voltar a rolar.
    assert_selector "html:not(.overflow-hidden)"

    # O botão Fechar também fecha.
    click_button "Ampliar foto"
    within("dialog[open]") { click_button "Fechar" }
    assert_no_selector "dialog[open]"

    # Sair com a ampliação aberta e voltar não reabre a foto (cache do Turbo).
    click_button "Ampliar foto"
    assert_selector "dialog[open]"
    page.execute_script("Turbo.visit('/')")
    assert_current_path "/"
    page.go_back
    assert_selector "[data-gallery-target='main']"
    assert_no_selector "dialog[open]"
  end
end
