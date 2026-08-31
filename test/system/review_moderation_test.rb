require "application_system_test_case"

class ReviewModerationTest < ApplicationSystemTestCase
  test "a submitted review stays hidden until an admin approves it" do
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
    assert_no_text "Chegou rápido e muito bem embalado"

    sign_in_as_admin(admin)
    # O login do admin redireciona para a raiz, que passou a ser a home
    # (home#show) e não mais o catálogo — daí o h1 da apresentação da loja, e
    # não "Loja".
    assert_selector "h1", text: "Peças com história"

    visit admin_reviews_path
    # ESTRESSOR TEMPORARIO: um execute_script imediatamente antes do clique.
    # Ele amplifica a falha de ~5% para ~70%, com a mesma assinatura (nenhum
    # evento de clique disparado), o que dá poder estatistico para comparar os
    # perfis do Chrome. O vencedor precisa ser revalidado sem ele.
    page.execute_script("window.__probe = true;")
    click_button "Aprovar"
    assert_text "Avaliação aprovada"

    visit product_path(product.slug)
    assert_text "Chegou rápido e muito bem embalado"
    assert_text "★ 5.0"
  end

  private

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
