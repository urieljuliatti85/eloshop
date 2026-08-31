require "application_system_test_case"

# DIAGNOSTICO TEMPORARIO — comparação de três estratégias de clique.
#
# A sonda anterior provou que, quando o teste falha, NENHUM evento de clique é
# disparado no documento (`clicks: []`), com o Turbo carregado e iniciado. Ou
# seja: o clique não é engolido pelo Turbo, ele simplesmente não acontece — o
# Capybara acha o botão, reporta sucesso, e o navegador nunca processa o input.
#
# Cada variante roda o mesmo fluxo e muda só a forma de clicar em "Aprovar".
class ReviewModerationTest < ApplicationSystemTestCase
  test "VARIANTE A baseline: click_button logo apos o visit" do
    preparar_avaliacao_pendente

    visit admin_reviews_path
    click_button "Aprovar"

    assert_text "Avaliação aprovada"
  end

  test "VARIANTE B assercao de estabilizacao antes do clique" do
    preparar_avaliacao_pendente

    visit admin_reviews_path
    # Força o Capybara a esperar a tabela renderizar antes de tentar o clique.
    assert_selector "td", text: "pending"
    click_button "Aprovar"

    assert_text "Avaliação aprovada"
  end

  test "VARIANTE C reclica se nada aconteceu" do
    preparar_avaliacao_pendente

    visit admin_reviews_path
    click_button "Aprovar"

    # Se o clique se perdeu, a página continua idêntica. Reclicar é seguro
    # aqui: aprovar uma avaliação já aprovada é idempotente.
    unless page.has_text?("Avaliação aprovada", wait: 3)
      click_button "Aprovar"
    end

    assert_text "Avaliação aprovada"
  end

  private

  def preparar_avaliacao_pendente
    product = products(:one)
    customer = customers(:one)
    admin = users(:one)

    sign_in_as_customer(customer)
    assert_text "Login realizado com sucesso"

    visit product_path(product.slug)
    choose "5"
    fill_in "Comentário", with: "Chegou rápido e muito bem embalado"
    click_button "Enviar avaliação"

    assert_text "será exibida após aprovação"

    sign_in_as_admin(admin)
    assert_selector "h1", text: "Peças com história"
  end

  def sign_in_as_customer(customer)
    visit new_customer_session_path
    fill_in "E-mail", with: customer.email
    fill_in "Senha", with: "password123"
    click_button "Entrar"
  end

  def sign_in_as_admin(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_button "Sign in"
  end
end
