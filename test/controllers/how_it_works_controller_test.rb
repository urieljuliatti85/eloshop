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

    assert_includes response.body, "8% nos 3 primeiros meses de vendas do seu ateliê e 15% depois disso"
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

    titles = css_select("[data-tab-name='atelie'] ol > li h3").map { |title| title.text.squish.sub(/\APasso \d+: /, "") }
    assert_equal [
      "Crie sua conta de artesão",
      "Informe o endereço do ateliê",
      "Conecte sua Conta Vendedor do Mercado Pago",
      "Cadastre uma chave PIX no Mercado Pago",
      "Conecte sua conta da SuperFrete",
      "Cadastre sua primeira peça",
      "Aguarde a aprovação da EloShop",
      "Receba os pedidos e envie",
      "Receba o pagamento"
    ], titles
    assert_select "[data-tab-name='atelie'] ol[start='8']"
  end

  test "seller tab invites to sign up and to log in" do
    get how_it_works_path(aba: "vende")

    assert_select "[data-tab-name='vende'] a[href='#{new_seller_registration_path}']", 2
    assert_select "[data-tab-name='vende'] a[href='#{seller_login_path}']"
  end

  # A SuperFrete entra no passo a passo junto com a etapa do painel: só onde
  # a cotação está ligada (Seller#superfrete_required?).
  test "seller tab shows the SuperFrete step only while remote quotes are enabled" do
    get how_it_works_path(aba: "vende")
    assert_includes response.body, "Conecte sua conta da SuperFrete"
    assert_includes response.body, "Para vender, conecte também a sua conta da SuperFrete"
    assert_includes response.body, "<strong>conta da SuperFrete conectada</strong>"

    previous = Rails.configuration.x.shipping.remote_quotes_enabled
    Rails.configuration.x.shipping.remote_quotes_enabled = false
    get how_it_works_path(aba: "vende")
    assert_not_includes response.body, "SuperFrete"
  ensure
    Rails.configuration.x.shipping.remote_quotes_enabled = previous
  end

  test "seller benefits and steps become carousels on mobile, without autoplay" do
    get how_it_works_path(aba: "vende")

    carousels = css_select("[data-tab-name='atelie'] [data-controller='carousel']")
    assert_equal 2, carousels.size
    assert carousels.all? { |carousel| carousel["data-carousel-interval-value"] == "0" }

    benefits, steps = carousels
    assert_equal 4, benefits.css("[data-carousel-target='slide']").size
    assert_equal 4, benefits.css("[data-carousel-target='dot']").size
    assert_equal 7, steps.css("[data-carousel-target='slide']").size
    assert_equal 7, steps.css("[data-carousel-target='dot']").size
    assert_equal "01", steps.at_css(".fluxo__selo-numero").text
    assert carousels.all? { |carousel| carousel.at_css("[data-carousel-target='controls']").key?("hidden") }
  end

  # "Quem vende" em dois grupos (ADR 007): o ateliê abre por padrão, o
  # armarinho por `?grupo=armarinho`.
  test "seller tab splits into the atelier and distributor groups, atelier first" do
    get how_it_works_path(aba: "vende")

    assert_select "[role='tab'][data-tab-name='atelie'][aria-selected='true']"
    assert_select "[data-tabs-target='panel'][data-tab-name='atelie']:not([hidden])"
    assert_select "[data-tabs-target='panel'][data-tab-name='armarinho'][hidden]"

    get how_it_works_path(aba: "vende", grupo: "qualquer")
    assert_select "[data-tabs-target='panel'][data-tab-name='atelie']:not([hidden])"
  end

  test "the old distribuidor group in the URL still opens the armarinho group" do
    get how_it_works_path(aba: "vende", grupo: "distribuidor")

    assert_select "[data-tabs-target='panel'][data-tab-name='armarinho']:not([hidden])"
  end

  test "distributor group opens from the URL and lists its own steps and doors" do
    get how_it_works_path(aba: "vende", grupo: "armarinho")

    assert_select "[data-tabs-target='panel'][data-tab-name='armarinho']:not([hidden])"
    assert_select "[role='tab'][data-tab-name='armarinho'][aria-selected='true']"
    titles = css_select("[data-tab-name='armarinho'] ol > li h3").map { |title| title.text.squish.sub(/\APasso \d+: /, "") }
    assert_equal [
      "Crie a conta do seu armarinho",
      "Conecte sua Conta Vendedor do Mercado Pago",
      "Cadastre uma chave PIX no Mercado Pago",
      "Aguarde a aprovação da EloShop",
      "Cadastre seus insumos",
      "Receba os pedidos e envie",
      "Receba o pagamento"
    ], titles
    assert_select "[data-tab-name='armarinho'] ol[start='6']"

    # Mesmo molde do ateliê: vantagens e passos viram carrossel no celular.
    carousels = css_select("[data-tab-name='armarinho'] [data-controller='carousel']")
    assert_equal [ 4, 5 ], carousels.map { |carousel| carousel.css("[data-carousel-target='slide']").size }
    assert_select "[data-tab-name='armarinho'] a[href='#{new_distributor_registration_path}']"
    assert_select "[data-tab-name='armarinho'] a[href='#{distributor_login_path}']"
    assert_select "[data-tab-name='armarinho'] a[href='#{new_seller_registration_path}']", 0
  end

  # Com o cadastro desligado (produção, até o advogado revisar os termos), a
  # página não leva a um 404: diz que abre em breve e mantém o login.
  test "distributor group says signup opens soon while the signup is switched off" do
    Rails.configuration.x.distributors.signup_enabled = false
    get how_it_works_path(aba: "vende", grupo: "armarinho")

    assert_select "[data-tab-name='armarinho'] a[href='#{new_distributor_registration_path}']", 0
    assert_includes response.body, "O cadastro de armarinhos abre em breve."
    assert_select "[data-tab-name='armarinho'] a[href='#{distributor_login_path}']"
  ensure
    Rails.configuration.x.distributors.signup_enabled = true
  end
end
