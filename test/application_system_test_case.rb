require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Sem isso, o Chrome passa a bloquear cliques em qualquer teste que logue
  # (formulário com campo password) mais de duas vezes na mesma sessão do
  # browser: o gerenciador de senhas intercepta a interação sem lançar
  # exceção, sem erro no console e sem sequer registrar a tentativa de
  # navegação no histórico (Page.getNavigationHistory) — o clique acontece,
  # mas nenhuma requisição chega ao servidor. Reproduzido de forma
  # determinística (sempre a partir da 3ª navegação pós-login na mesma
  # sessão) e confirmado como a causa raiz do teste de sistema instável
  # registrado no débito técnico do ROADMAP.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |driver_option|
    driver_option.add_argument("--password-store=basic")
    driver_option.add_preference("credentials_enable_service", false)
    driver_option.add_preference("profile.password_manager_enabled", false)
    driver_option.add_preference("profile.password_manager_leak_detection", false)
  end

  SCREEN_SIZE = [ 1400, 1400 ].freeze

  # Todo teste começa na janela padrão, sem emulação de celular. A sessão do
  # Chrome é reaproveitada entre testes, e um teste que encolhe a janela
  # (`resize_to`) ou emula um celular (CDP) sem desfazer deixa a tela pequena
  # para os seguintes: com a ordem aleatória, quebrava testes que dependem da
  # posição na tela. Foi o que derrubou o system-test do CI no #343 (a lista
  # de erros do cadastro do ateliê ficava abaixo de uma janela de 800 px
  # deixada por sell_menu_test), sem relação com o código do PR. Desfazer
  # aqui, e não em cada teste, para um teste novo não reabrir o problema.
  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
  end
end

# O default do Capybara (2s) é curto demais para o runner do CI, mais lento
# que uma máquina local — fluxos com submit + redirect + full page render
# (ex.: aprovar avaliação no admin) intermitentemente estouravam esse prazo
# só no GitHub Actions, nunca localmente.
Capybara.default_max_wait_time = 5

# Radios/checkboxes visualmente escondidos (padrão "peer sr-only" + label
# estilizado, usado no seletor de variante) só são clicáveis pelo label —
# sem isso, choose/check/uncheck tentam clicar no input em si e falham com
# ElementClickInterceptedError.
Capybara.automatic_label_click = true

# Botões só com ícone (ex.: coração de favoritar) dependem do aria-label
# para nome acessível — sem isso, click_button/find_button não os localiza
# pelo texto visível para o usuário de leitor de tela.
Capybara.enable_aria_label = true
