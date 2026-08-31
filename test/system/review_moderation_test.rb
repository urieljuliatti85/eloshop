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
    install_flake_probe
    click_button "Aprovar"
    begin
      assert_text "Avaliação aprovada"
    rescue Minitest::Assertion
      puts "== DIAGNOSTICO DO FLAKE =="
      puts read_flake_probe
      raise
    end

    visit product_path(product.slug)
    assert_text "Chegou rápido e muito bem embalado"
    assert_text "★ 5.0"
  end

  private

  # DIAGNOSTICO TEMPORARIO. Registra, no navegador, se o clique vira um evento
  # submit e se alguem chamou preventDefault nele. Isso separa duas hipoteses
  # que o log do servidor nao distingue: o clique nao alcancou o formulario, ou
  # alcancou e o submit foi engolido antes de virar requisicao.
  #
  # Se a pagina navegar (caso de sucesso), a sonda se perde junto - o que ja e
  # informacao: significa que o submit funcionou.
  def install_flake_probe
    page.execute_script(<<~JS)
      window.__diag = {
        turbo: !!window.Turbo,
        started: !!(window.Turbo && window.Turbo.session && window.Turbo.session.started),
        forms: document.querySelectorAll("form").length,
        submits: [],
        clicks: []
      };
      document.addEventListener("submit", function (e) {
        window.__diag.submits.push({
          fase: "capture",
          action: e.target && e.target.action,
          prevented: e.defaultPrevented
        });
      }, true);
      document.addEventListener("submit", function (e) {
        window.__diag.submits.push({
          fase: "bubble",
          action: e.target && e.target.action,
          prevented: e.defaultPrevented
        });
      }, false);
      document.addEventListener("click", function (e) {
        window.__diag.clicks.push({
          tag: e.target && e.target.tagName,
          type: e.target && e.target.type,
          texto: ((e.target && e.target.value) || "").slice(0, 20)
        });
      }, true);
    JS
  end

  def read_flake_probe
    page.evaluate_script("JSON.stringify(window.__diag || 'PAGINA NAVEGOU (sonda perdida)')")
  rescue StandardError => e
    "sonda ilegivel: #{e.class}"
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
