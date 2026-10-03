require "application_system_test_case"

# Campos obrigatórios do cadastro de produto: borda vermelha, mensagem e
# rolagem até o primeiro campo vazio. É o celular que motiva a rolagem — o
# teclado e o scroll escondem o campo, e o balão nativo do navegador some
# sem o vendedor entender o que faltou. `resize_to` não emula viewport
# estreito de verdade; só o CDP define a largura real.
class ProductRequiredFieldsTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 390, height: 844, deviceScaleFactor: 2, mobile: true)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  # Um login só: o limite de tentativas de login estoura com um por teste.
  test "required fields flag, scroll to the first empty one and follow the availability type" do
    sign_in_seller(users(:seller))
    visit new_seller_product_path
    assert_selector "form[data-controller='required-fields']"

    # Nada vermelho ao abrir o formulário.
    assert_no_selector "[aria-invalid='true']"

    # Enviar vazio: não envia, marca os dois obrigatórios (e, sem bloquear,
    # peso e dimensões, que só são exigidos para publicar) e leva ao primeiro.
    click_button "Salvar produto"
    assert_current_path new_seller_product_path
    assert_selector "[aria-invalid='true']", count: 6
    assert_text "Preencha este campo.", count: 2
    assert_text "Obrigatório para publicar.", count: 4
    assert_equal "product_name", page.evaluate_script("document.activeElement.id")
    assert_in_viewport "product_name"

    # Preencher o campo limpa o erro dele.
    fill_in "Nome", with: "Vaso azul"
    assert_selector "[aria-invalid='true']", count: 5

    # Prazo de produção só é obrigatório (e marcado) para sob encomenda.
    assert_no_selector "label[for='product_production_time_min_days'] [data-required-fields-target='marker']", visible: :visible
    select "Sob encomenda", from: "Disponibilidade"
    assert_selector "label[for='product_production_time_min_days'] [data-required-fields-target='marker']", visible: :visible
    assert_selector "label[for='product_production_time_max_days'] [data-required-fields-target='marker']", visible: :visible

    fill_in "Preço (R$)", with: "500"
    click_button "Salvar produto"
    assert_current_path new_seller_product_path
    assert_selector "[aria-invalid='true']", count: 6
    assert_equal "product_production_time_min_days", page.evaluate_script("document.activeElement.id")

    # Peso e dimensões têm asterisco, mas não impedem salvar como rascunho.
    assert_selector "label[for='product_weight_grams'] [data-required-fields-target='marker']", visible: :visible
    select "Estoque padrão", from: "Disponibilidade"
    click_button "Salvar produto"
    assert_text "Produto criado com sucesso."
  end

  private

  # A rolagem é suave: espera ela terminar antes de medir.
  def assert_in_viewport(id)
    script = <<~JS
      (() => { const r = document.getElementById("#{id}").getBoundingClientRect(); return r.top >= 0 && r.bottom <= window.innerHeight })()
    JS
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    sleep 0.1 until page.evaluate_script(script) || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    assert page.evaluate_script(script), "##{id} fora da área visível"
  end

  def sign_in_seller(user)
    visit seller_login_path
    fill_in "E-mail", with: user.email_address
    fill_in "Senha", with: "password"
    click_button "Entrar"
    assert_current_path seller_root_path
  end
end
