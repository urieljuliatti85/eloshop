require "application_system_test_case"

class CpfInputTest < ApplicationSystemTestCase
  test "formats the CPF while typing on the artisan signup" do
    visit new_seller_registration_path
    await_cpf_input_controller

    type_cpf "1234"
    assert_field "CPF *", with: "123.4"

    type_cpf "12345678909"
    assert_field "CPF *", with: "123.456.789-09"

    # Separador digitado é ignorado, e o que passa de 11 dígitos é descartado.
    type_cpf "123.456.789-0999"
    assert_field "CPF *", with: "123.456.789-09"
  end

  test "validates the CPF on the signup before it is sent" do
    visit new_seller_registration_path
    await_cpf_input_controller

    # Dígitos verificadores errados: a mensagem aparece assim que o CPF fica
    # completo, e o navegador não deixa enviar.
    type_cpf "52998224724"
    assert_selector "#seller_cpf_check", text: "CPF inválido"
    assert_equal false, page.evaluate_script("document.getElementById('seller_cpf').checkValidity()")

    # Incompleto não é cobrado enquanto a pessoa digita, só ao sair do campo.
    type_cpf "5299"
    assert_no_selector "#seller_cpf_check", visible: true
    find_field("Nome do ateliê *").click
    assert_selector "#seller_cpf_check", text: "O CPF tem 11 números. Faltam 7."

    type_cpf "52998224725"
    assert_no_selector "#seller_cpf_check", visible: true
    assert_equal true, page.evaluate_script("document.getElementById('seller_cpf').checkValidity()")
  end

  private

  # Mesmo motivo de PriceInputTest#await_price_input_controller: o `visit`
  # volta antes de o Stimulus ligar o `data-action`, então a espera confirma
  # que um `input` sintético já passa pela máscara.
  def await_cpf_input_controller
    binding_active_script = <<~JS
      (function() {
        const el = document.getElementById("seller_cpf");
        el.value = "1234";
        el.dispatchEvent(new Event("input", { bubbles: true }));
        const active = el.value === "123.4";
        el.value = "";
        return active;
      })()
    JS

    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until page.evaluate_script(binding_active_script)
    end
  end

  def type_cpf(value)
    field = find_field("CPF *")
    field.set("")
    field.send_keys(value)
  end
end
