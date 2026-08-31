require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # DIAGNOSTICO TEMPORARIO. CHROME_PROFILE seleciona a configuração do
  # navegador para comparar taxas de falha do flake de ReviewModerationTest.
  # Sem a variável, o comportamento é o de sempre.
  CHROME_ARGS = {
    # Configuração atual do projeto, para servir de controle.
    "baseline" => [],

    # Headless novo do Chrome: usa o mesmo pipeline de renderização do
    # navegador real, em vez da implementação antiga e separada. Se a falha
    # vier de input descartado antes do primeiro frame, é aqui que muda.
    "new_headless" => [ "--headless=new" ],

    # Desliga caminhos que podem atrasar ou suspender o pipeline de
    # renderização em container: GPU ausente, /dev/shm pequeno, e o Chrome
    # despriorizando janelas que considera ocultas — o que num headless é
    # sempre.
    "hardened" => [
      "--disable-gpu",
      "--disable-dev-shm-usage",
      "--disable-renderer-backgrounding",
      "--disable-backgrounding-occluded-windows",
      "--disable-features=CalculateNativeWinOcclusion",
      "--force-device-scale-factor=1"
    ]
  }.freeze

  EXTRA_CHROME_ARGS = CHROME_ARGS.fetch(ENV.fetch("CHROME_PROFILE", "baseline"), [])

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    EXTRA_CHROME_ARGS.each { |arg| options.add_argument(arg) }
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
