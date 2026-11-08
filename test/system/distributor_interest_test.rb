require "application_system_test_case"

# Pré-cadastro de armarinhos no navegador (ADR 007). O checkbox de autorização é
# `required`: sem ele, o navegador barra o envio e a requisição nem chega ao
# servidor. Por isso o teste confere a validade do campo no navegador, não a
# mensagem do Rails (essa é coberta em spec/requests/distributor_interests_spec.rb,
# "requires consent"). Com a autorização marcada, o envio passa e grava o contato.
#
# O token do formulário exige 3 segundos desde a renderização (ContactMessage),
# então o teste espera antes do envio. O Turnstile fica desligado em teste (sem
# TURNSTILE_SECRET_KEY), por isso não há stub aqui.
class DistributorInterestTest < ApplicationSystemTestCase
  test "blocks submission without consent and accepts it once consent is given" do
    visit new_distributor_interest_path

    fill_in "E-mail", with: "interesse.sistema@example.com"
    fill_in "Telefone com WhatsApp", with: "(11) 98765-4321"

    assert_no_difference "DistributorInterest.count" do
      click_button "Quero ser avisado"
      # O navegador não envia o formulário sem o checkbox: o campo fica inválido.
      assert_equal false, page.evaluate_script("document.getElementById('consent').checkValidity()")
      assert_current_path new_distributor_interest_path
      assert_no_text "Recebemos seu interesse"
    end

    # Espera o tempo mínimo de preenchimento do token, desde a renderização.
    sleep 3
    check "Autorizo a EloShop"

    assert_difference "DistributorInterest.count", 1 do
      click_button "Quero ser avisado"
      assert_text "Recebemos seu interesse. Avisaremos quando o pré-cadastro abrir."
    end

    interest = DistributorInterest.find_by!(email_address: "interesse.sistema@example.com")
    assert_predicate interest.consent_at, :present?
  end
end
