require "test_helper"

class HowItWorksControllerTest < ActionDispatch::IntegrationTest
  test "page is publicly accessible and shows both tabs" do
    get how_it_works_path

    assert_response :success
    assert_select "h1", "Como funciona"
    assert_select "[data-tab-name='compra']", 2
    assert_select "[data-tab-name='vende']", 2
  end

  test "explains the launch commission and that there is no monthly fee" do
    get how_it_works_path

    assert_includes response.body, "8% nos 3 primeiros meses depois da aprovação do seu ateliê e 15% depois disso"
    assert_includes response.body, "Não há mensalidade, no momento."
  end

  test "seller tab requires a PIX key on the connected Mercado Pago account" do
    get how_it_works_path

    assert_includes response.body, "Exigência obrigatória:"
    assert_includes response.body, "chave PIX cadastrada"
  end
end
