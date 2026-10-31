require "application_system_test_case"

class SellerRegistrationErrorsTest < ApplicationSystemTestCase
  # Quem clica em "Criar cadastro" está no fim da página, e a lista de erros
  # fica no topo. O formulário voltava sem nenhum aviso à vista e o artesão
  # não sabia o que tinha dado errado.
  test "brings the error list into view and repeats each error under its field" do
    # Um CPF válido que já tem ateliê: o navegador aceita (a máscara só
    # confere o formato e os dígitos) e o servidor recusa.
    Seller.create!(name: "Ateliê Dono do CPF", owner_full_name: "Dona Primeira", cpf: "52998224725")
    visit new_seller_registration_path

    fill_in "Nome do ateliê *", with: "Ateliê Sistema"
    fill_in "Nome completo do proprietário *", with: "Dona Sistema"
    fill_in "CPF *", with: "52998224725"
    fill_in "E-mail *", with: "sistema-#{SecureRandom.hex(3)}@example.com"
    fill_in "Senha *", with: "password123"
    fill_in "Confirmar senha *", with: "outra-senha-123"
    check "terms_accepted"
    click_on "Criar cadastro"

    assert_selector "#erros-cadastro", text: "Corrija 2 erros para continuar:"
    assert_selector "#seller_cpf_error", text: "CPF já está cadastrado para outro ateliê. Cada CPF pode ter um único ateliê na EloShop."
    assert_link "Entrar no painel do ateliê"
    assert_selector "#user_password_confirmation_error", text: "Confirmação da senha não é igual a Senha"
    assert_equal "erros-cadastro", page.evaluate_script("document.activeElement.id")

    top = page.evaluate_script("document.getElementById('erros-cadastro').getBoundingClientRect().top")
    assert_operator top, :<, page.evaluate_script("window.innerHeight"), "a lista de erros precisa estar à vista"
  end
end
