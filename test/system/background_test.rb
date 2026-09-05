require "application_system_test_case"

class BackgroundTest < ApplicationSystemTestCase
  # O fundo vinha de um <style> injetado no <head> pela própria página. O
  # Turbo Drive troca só o <body> ao navegar, então aquele bloco não era
  # reexecutado e a imagem só aparecia depois de um reload completo.
  test "the background image survives a Turbo navigation" do
    visit products_path
    assert_no_selector "body.home-background"

    # Navegação por link (Turbo), sem recarregar a página.
    within("header nav") { click_link "Início" }
    assert_selector "body.home-background"

    assert_includes body_background_image, "home-background",
      "o fundo deveria vir do CSS, sem depender de um reload"
  end

  private

  def body_background_image
    page.evaluate_script("getComputedStyle(document.body).backgroundImage")
  end
end
