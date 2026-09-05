require "application_system_test_case"

class PriceInputTest < ApplicationSystemTestCase
  # Um login só para todos os casos: `SessionsController` limita a 10
  # tentativas em 3 minutos, e um login por teste estourava o limite com a
  # suíte inteira rodando.
  test "formats the price as brazilian currency while typing" do
    sign_in_as_admin(users(:one))
    assert_selector "h1", text: "Dashboard"

    visit new_admin_product_path

    # Os dígitos entram pela direita: "4000" vira "40,00" sem que ninguém
    # digite a vírgula.
    fill_in "Preço (R$)", with: "4000"
    assert_field "Preço (R$)", with: "40,00"

    # A vírgula aparece já no primeiro dígito.
    fill_in "Preço (R$)", with: "4"
    assert_field "Preço (R$)", with: "0,04"

    # O separador de milhar entra sozinho quando o valor cresce.
    fill_in "Preço (R$)", with: "129990"
    assert_field "Preço (R$)", with: "1.299,90"

    # Apagar tudo deixa o campo vazio, não "0,00" — preço opcional em branco
    # não é um preço decidido.
    fill_in "Preço (R$)", with: ""
    assert_field "Preço (R$)", with: ""
  end

  private

  def sign_in_as_admin(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Entrar"
  end
end
