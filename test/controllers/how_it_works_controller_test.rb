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

  test "opens the tab chosen in the URL already on the server" do
    get how_it_works_path(aba: "vende")

    assert_select "[data-tabs-target='panel'][data-tab-name='vende']:not([hidden])"
    assert_select "[data-tabs-target='panel'][data-tab-name='compra'][hidden]"
    assert_select "[role='tab'][data-tab-name='vende'][aria-selected='true']"
  end

  test "falls back to the buyer tab without or with an unknown tab" do
    [ how_it_works_path, how_it_works_path(aba: "qualquer") ].each do |path|
      get path

      assert_select "[data-tabs-target='panel'][data-tab-name='compra']:not([hidden])"
      assert_select "[data-tabs-target='panel'][data-tab-name='vende'][hidden]"
    end
  end

  test "seller tab lists the steps as numbered cards, in the panel order" do
    get how_it_works_path(aba: "vende")

    titles = css_select("[data-tab-name='vende'] ol > li h3").map { |title| title.text.squish.sub(/\APasso \d+: /, "") }
    assert_equal [
      "Crie sua conta de artesão",
      "Informe o endereço do ateliê",
      "Conecte sua Conta Vendedor do Mercado Pago",
      "Cadastre uma chave PIX no Mercado Pago",
      "Cadastre sua primeira peça",
      "Aguarde a aprovação da EloShop",
      "Receba os pedidos e envie",
      "Receba o pagamento"
    ], titles
    assert_select "[data-tab-name='vende'] ol[start='7']"
  end

  test "seller tab invites to sign up and to log in" do
    get how_it_works_path(aba: "vende")

    assert_select "[data-tab-name='vende'] a[href='#{new_seller_registration_path}']", 2
    assert_select "[data-tab-name='vende'] a[href='#{seller_login_path}']"
  end

  test "seller tab does not offer the Melhor Envio connection, blocked in production" do
    get how_it_works_path(aba: "vende")

    assert_not_includes response.body, "Melhor Envio"
  end
end
