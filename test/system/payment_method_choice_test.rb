require "application_system_test_case"

# O botão de cartão e a seção onde o Brick é montado vivem em blocos
# diferentes da view; enquanto ficaram em elementos irmãos, o data-action
# não alcançava o controller (Stimulus só liga um action ao controller que
# o contém) e o clique não fazia nada — sem erro no console. Só um clique
# real revela isso: as request specs veem o botão no HTML e passam.
class PaymentMethodChoiceTest < ApplicationSystemTestCase
  setup do
    @order = orders(:one)
    # A tela só oferece a escolha do meio enquanto não houver tentativa:
    # com um Payment existente, payments#new renderiza o estado dela (a
    # fixture traz um PIX pendente para este pedido).
    @order.payments.destroy_all
    @seller = @order.seller_order.seller
    @seller.update_columns(
      mercado_pago_user_id: "SYSTEM-TEST-USER",
      mercado_pago_access_token_ciphertext: "cipher",
      mercado_pago_refresh_token_ciphertext: "cipher",
      mercado_pago_public_key: "TEST-SYSTEM-TEST-PUBLIC-KEY"
    )

    customer = @order.customer
    visit new_customer_session_path
    fill_in "E-mail", with: customer.email
    fill_in "Senha", with: "password123"
    click_button "Entrar"
    assert_no_current_path new_customer_session_path, wait: 5
  end

  test "choosing card mounts the brick container" do
    visit new_order_payment_path(@order)

    assert_button "Pagar com cartão de crédito"
    assert_no_selector "[data-card-payment-brick-target='container']"

    click_button "Pagar com cartão de crédito"

    # Afirma o elo que quebrou: o clique alcançar o controller e o clone do
    # <template> entrar no DOM. `visible: false` porque o container fica
    # vazio — quem preenche os iframes é o SDK do Mercado Pago, que não
    # carrega aqui; os campos do cartão são cross-origin e ficam fora do
    # alcance do Capybara de qualquer forma.
    assert_selector "[data-card-payment-brick-target='container']", visible: false
  end

  test "card option is hidden when the seller has no public key" do
    @seller.update_columns(mercado_pago_public_key: nil)

    visit new_order_payment_path(@order)

    assert_no_button "Pagar com cartão de crédito"
    assert_button "Pagar com PIX"
  end
end
