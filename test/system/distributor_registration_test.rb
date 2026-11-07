require "application_system_test_case"

# Conveniências do formulário de cadastro do distribuidor que só existem no
# navegador (ADR 007): checagem do nome ao vivo e máscaras de CPF e CNPJ. O
# servidor valida tudo de novo (spec/requests/distributor_portal_spec.rb).
class DistributorRegistrationTest < ApplicationSystemTestCase
  test "checks the name while typing, against ateliers and distributors" do
    Seller.create!(name: "Fios da Serra", owner_full_name: "Ana", cpf: "52998224725")
    visit new_distributor_registration_path

    fill_in "Nome do armarinho *", with: "Fios da Serra"
    assert_text "Já existe um ateliê ou um armarinho com esse nome"
    click_button 'Usar "Fios da Serra 2"'
    assert_text "Nome disponível. Endereço: /armarinhos/fios-da-serra-2"
  end

  test "formats and checks the CPF while typing" do
    visit new_distributor_registration_path

    fill_in "CPF do responsável *", with: "52998224725"
    assert_field "CPF do responsável *", with: "529.982.247-25"

    fill_in "CPF do responsável *", with: "52998224700"
    assert_text "CPF inválido"
  end

  test "formats the CNPJ, numeric or alphanumeric, and checks it while typing" do
    visit new_distributor_registration_path

    fill_in "CNPJ", with: "11222333000181"
    assert_field "CNPJ", with: "11.222.333/0001-81"
    assert_no_text "CNPJ inválido"

    fill_in "CNPJ", with: "12abc34501de35"
    assert_field "CNPJ", with: "12.ABC.345/01DE-35"
    assert_no_text "CNPJ inválido"

    fill_in "CNPJ", with: "11222333000100"
    assert_text "CNPJ inválido"

    fill_in "CNPJ", with: "112223"
    find_field("CNPJ").send_keys(:tab)
    assert_text "O CNPJ tem 14 caracteres. Faltam 8."
  end
end
