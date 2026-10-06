require "application_system_test_case"

class CustomerEmailAvailabilityTest < ApplicationSystemTestCase
  test "shows green for a free e-mail and red for a taken or malformed one while typing" do
    visit new_customer_path

    fill_in "E-mail", with: "livre@example.com"
    assert_selector "#customer_email_status.text-green-700", text: "E-mail disponível"
    assert_selector "input.border-green-600"

    fill_in "E-mail", with: customers(:one).email
    assert_selector "#customer_email_status.text-red-700", text: "já tem cadastro"
    assert_selector "input.border-red-400"

    fill_in "E-mail", with: "isso@nao"
    assert_selector "#customer_email_status.text-red-700", text: "e-mail válido"
  end

  test "does not let a taken e-mail be submitted" do
    visit new_customer_path

    fill_in "Nome", with: "Outra Maria"
    fill_in "E-mail", with: customers(:one).email
    assert_selector "#customer_email_status.text-red-700"
    fill_in "Senha", with: "password123"
    fill_in "Confirmar senha", with: "password123"
    click_button "Criar conta"

    assert_current_path new_customer_path
    assert_equal 0, Customer.where(name: "Outra Maria").count
  end
end
