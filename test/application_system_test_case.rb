require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
end

# Radios/checkboxes visualmente escondidos (padrão "peer sr-only" + label
# estilizado, usado no seletor de variante) só são clicáveis pelo label —
# sem isso, choose/check/uncheck tentam clicar no input em si e falham com
# ElementClickInterceptedError.
Capybara.automatic_label_click = true

# Botões só com ícone (ex.: coração de favoritar) dependem do aria-label
# para nome acessível — sem isso, click_button/find_button não os localiza
# pelo texto visível para o usuário de leitor de tela.
Capybara.enable_aria_label = true
