require "application_system_test_case"

class ReviewModerationTest < ApplicationSystemTestCase
  test "a submitted review stays hidden until an admin approves it" do
    product = products(:one)
    customer = customers(:one)
    admin = users(:one)

    sign_in_as_customer(customer)
    assert_text "Login realizado com sucesso"

    visit product_path(product.seller, product.slug)
    choose "5"
    fill_in "Comentário", with: "Chegou rápido e muito bem embalado"
    click_button "Enviar avaliação"

    assert_text "será exibida após aprovação"
    assert_no_text "Chegou rápido e muito bem embalado"

    sign_in_as_admin(admin)
    assert_selector "h1", text: "Dashboard"

    visit admin_reviews_path
    # O click por coordenadas do Selenium era engolido intermitentemente no
    # runner do GitHub sem sequer enviar o PATCH. Submeter o botão nativo
    # continua exercitando formulário, controller, redirect e flash completos.
    find_button("Aprovar").native.submit
    assert_text "Avaliação aprovada"

    visit product_path(product.seller, product.slug)
    assert_text "Chegou rápido e muito bem embalado"
    assert_text "★ 5.0"
  end

  test "a seller replies to an approved review and the reply becomes public" do
    seller = sellers(:approved)
    product = products(:one)
    product.update!(seller: seller)
    customer = customers(:one)
    review = customer.reviews.create!(product: product, rating: 5, comment: "Chegou rápido e muito bem embalado")
    review.approve!
    seller_user = User.create!(
      email_address: "seller-#{SecureRandom.hex(4)}@example.com", password: "password123", role: :seller, seller: seller
    )
    SellerTermsAcceptance.record!(user: seller_user, seller: seller, request: ActionDispatch::TestRequest.create)

    visit seller_login_path
    fill_in "E-mail", with: seller_user.email_address
    fill_in "Senha", with: "password123"
    click_button "Entrar"
    assert_text "Crie, publique e acompanhe cada venda"

    visit seller_reviews_path
    assert_text "Chegou rápido e muito bem embalado"
    fill_in "Responder", with: "Que bom que gostou!"
    click_button "Publicar resposta"

    assert_text "Resposta publicada"
    assert_text "Que bom que gostou!"

    visit product_path(product.seller, product.slug)
    assert_text "RESPOSTA DO ATELIÊ"
    assert_text "Que bom que gostou!"
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
    click_button "Entrar"
  end
end
