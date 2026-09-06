require "application_system_test_case"

class PriceInputTest < ApplicationSystemTestCase
  # Um login só para todos os casos: `SessionsController` limita a 10
  # tentativas em 3 minutos, e um login por teste estourava o limite com a
  # suíte inteira rodando.
  test "formats the price as brazilian currency while typing" do
    sign_in_as_admin(users(:one))
    assert_selector "h1", text: "Dashboard"

    visit new_admin_product_path
    await_price_input_controller

    # `fill_in` digita caractere a caractere, e o campo reformata a cada
    # tecla: sem zerar antes, o dígito novo entra sobre o valor anterior e a
    # asserção lê o resultado da soma dos dois. Daí o preenchimento explícito
    # em vez de um `fill_in` direto.
    type_price "4000"
    assert_field "Preço (R$)", with: "40,00"

    # A vírgula aparece já no primeiro dígito.
    type_price "4"
    assert_field "Preço (R$)", with: "0,04"

    # O separador de milhar entra sozinho quando o valor cresce.
    type_price "129990"
    assert_field "Preço (R$)", with: "1.299,90"

    # Apagar tudo deixa o campo vazio, não "0,00" — preço opcional em branco
    # não é um preço decidido.
    type_price ""
    assert_field "Preço (R$)", with: ""
  end

  private

  # A máscara só existe depois que o Stimulus baixa e conecta o controller —
  # e o `visit` do Capybara devolve o controle assim que o HTML carrega, sem
  # esperar por isso. No runner do CI, mais lento que uma máquina local, os
  # `send_keys` chegavam antes da conexão: sem handler de `input`, o campo
  # ficava com o texto cru e a asserção lia "" em vez de "40,00".
  #
  # Esperar o campo vazio não serve de barreira (vazio é vazio com ou sem
  # máscara), então a espera pergunta ao próprio Stimulus se o controller já
  # está conectado ao elemento.
  #
  # `getControllerForElementAndIdentifier` só confirma que a instância JS do
  # controller existe — não que o binding do `data-action="input->..."` já
  # foi registrado pelo Application do Stimulus (são passos distintos dentro
  # do mesmo ciclo de conexão). No runner do CI o gap entre os dois já se
  # mostrou grande o bastante pra um `send_keys` disparar `input` antes do
  # binding existir, mesmo com o controller já "conectado" — por isso a
  # espera termina só depois de confirmar que um evento `input` sintético
  # realmente aciona `format()` (o campo passa a refletir o valor definido
  # via `value` antes do disparo), não apenas que o controller existe.
  def await_price_input_controller
    field_id = find_field("Preço (R$)")[:id]
    connected_script = <<~JS
      !!(window.Stimulus && window.Stimulus.getControllerForElementAndIdentifier(
        document.getElementById(#{field_id.to_json}), "price-input"))
    JS
    binding_active_script = <<~JS
      (function() {
        const el = document.getElementById(#{field_id.to_json});
        el.value = "700";
        el.dispatchEvent(new Event("input", { bubbles: true }));
        const active = el.value === "7,00";
        el.value = "";
        return active;
      })()
    JS

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    loop do
      break if page.evaluate_script(connected_script) && page.evaluate_script(binding_active_script)

      raise Capybara::ElementNotFound, "o controller price-input não conectou a tempo" if
        Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  # Zera o campo antes de digitar e espera o valor assentar: o Capybara
  # preenche tecla a tecla, e o controller reformata a cada uma.
  def type_price(value)
    field = find_field("Preço (R$)")
    field.set("")
    assert_field "Preço (R$)", with: ""
    field.send_keys(value) unless value.empty?
  end

  def sign_in_as_admin(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Entrar"
  end
end
