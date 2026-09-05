require "application_system_test_case"

class HomeCarouselTest < ApplicationSystemTestCase
  test "the visitor reaches the artisan banner through the carousel controls" do
    visit root_path

    # Os dois banners estão no HTML desde o começo — o carrossel move a faixa,
    # não troca o conteúdo.
    assert_text "Peças com história, feitas à mão"
    assert_text "Venda suas peças mais criativas através do nosso Ateliê"

    # Os controles só existem com JavaScript; sem ele a rolagem da faixa dá
    # conta e um botão inerte seria pior que nenhum.
    assert_selector "button[aria-label='Próximo banner']"

    click_button "Próximo banner"
    # Dentro do carrossel: o mesmo rótulo existe no topo, no menu da direita.
    within("[aria-roledescription='carrossel']") { click_link "Seja um artesão" }

    assert_current_path new_seller_registration_path
  end
end
