require "application_system_test_case"

# Driver genérico de auditoria mobile: visita uma lista de rotas sob um
# viewport real (via CDP), reporta vazamento de largura horizontal e salva
# um screenshot de cada uma para inspeção visual. Não é um teste de
# regressão de uma feature específica — é a ferramenta que um agente roda
# ad-hoc depois de mexer em CSS/layout, para auditar ou verificar uma
# página.
#
# LIMITAÇÕES CONHECIDAS (descobertas tentando quebrar este driver de
# propósito, reintroduzindo o bug real que existiu em
# app/views/seller_portal/products/index.html.erb antes de ser corrigido):
#
# 1. scrollWidth do <html> só pega vazamento de LAYOUT (algo empurrando a
#    página inteira além da largura do viewport). Não pega conteúdo cortado
#    dentro de um container com `overflow-hidden` que nunca vazou — por
#    isso o screenshot de cada rota é sempre salvo, mesmo quando o
#    scrollWidth bate certo: é a única forma confiável de flagar esse caso.
# 2. Uma checagem automática por elemento ("todo elemento com
#    overflow-hidden cujo scrollWidth excede o clientWidth") foi tentada e
#    descartada: neste design system, cards decorativos usam
#    `overflow-hidden` de propósito com formas absolutamente posicionadas
#    que estouram o container por design (ver dashboard.html.erb, os cards
#    com `<span class="absolute -bottom-12 -right-8 size-44 rounded-full
#    ...">`) — a checagem sinalizava esses como "bug" toda vez. Corrigir
#    isso com uma allowlist de seletores (.sr-only, [data-carousel-target])
#    ainda deixava passar os cards decorativos, e uma allowlist que também
#    cobrisse esses viraria uma lista sempre desatualizada conforme o
#    design evolui. Preferível: revisar o screenshot, ou escrever um teste
#    dedicado que clique no elemento interativo esperado (como
#    test/system/seller_portal_mobile_test.rb faz).
# 3. Com poucas linhas (fixtures de teste costumam ter poucas), uma tabela
#    larga pode nem chegar a precisar de scroll horizontal em 390px — o bug
#    de "tabela larga sem wrapper responsivo" só se manifesta com dado
#    suficiente. Rodar o driver contra dados de seed tende a expor mais que
#    rodar contra as fixtures do Minitest.
# 4. `click_link`/`find(...).click` do Capybara+Selenium rolam até o
#    elemento antes de clicar, então um teste que clica com sucesso NÃO
#    prova que o elemento é alcançável por um usuário real sem rolar um
#    container escondido. Combine sempre com o screenshot.
#
# Uso:
#   MOBILE_PATHS="/produtos,/painel" bin/rails test \
#     .claude/skills/run-mobile-responsive-check/driver_test.rb
#
# Cada entrada em MOBILE_PATHS é uma path literal (sem host). Para rotas que
# exigem sessão (ex.: /painel/*), o driver loga como seller (fixture
# :seller) antes de visitar a primeira delas.
#
# MOBILE_WIDTH (default 390) e MOBILE_HEIGHT (default 844) controlam o
# viewport. Screenshots vão para tmp/screenshots/mobile-audit-<slug>.png —
# depois de rodar, olhe os arquivos: o driver só automatiza a navegação e a
# checagem de vazamento, não substitui a inspeção visual.
class MobileResponsiveDriverTest < ApplicationSystemTestCase
  WIDTH = (ENV["MOBILE_WIDTH"] || 390).to_i
  HEIGHT = (ENV["MOBILE_HEIGHT"] || 844).to_i

  setup do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: WIDTH, height: HEIGHT, deviceScaleFactor: 2, mobile: true)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "audits configured paths for horizontal overflow at mobile width" do
    paths = (ENV["MOBILE_PATHS"] || "/").split(",").map(&:strip)
    signed_in_seller = false
    failures = []

    paths.each do |path|
      if path.start_with?("/painel") && !signed_in_seller
        sign_in_seller
        signed_in_seller = true
      end

      visit path
      slug = path.gsub(%r{[^a-z0-9]+}i, "-").sub(/^-+|-+$/, "")
      slug = "root" if slug.empty?
      screenshot_path = Rails.root.join("tmp/screenshots/mobile-audit-#{slug}.png")
      page.save_screenshot(screenshot_path)

      # Uma página de erro (rota inexistente, 404, 500) não tem CSS da
      # aplicação e por acaso cabe em qualquer largura — sem essa checagem,
      # uma rota digitada errado passa como falso "OK" silencioso. Achado
      # ao verificar este driver: /painel/produtos (em português, rota
      # errada) reportava scrollWidth=390 mesmo sendo a tela de "Routing
      # Error" do Rails, porque a página de erro também cabe em 390px.
      if page.has_text?("Routing Error", wait: 0) || page.has_text?("We're sorry, but something went wrong", wait: 0)
        failures << "#{path}: página de erro, não a página esperada (rota errada?) — ver #{screenshot_path}"
        next
      end

      scroll_width = page.evaluate_script("document.documentElement.scrollWidth")
      if scroll_width > WIDTH
        failures << "#{path}: página vazou para #{scroll_width}px (esperado #{WIDTH}) — ver #{screenshot_path}"
      else
        puts "OK  #{path} (scrollWidth=#{scroll_width}) — inspecione #{screenshot_path}"
      end
    end

    assert_empty failures, "Overflow horizontal encontrado:\n#{failures.join("\n")}"
  end

  private

  def sign_in_seller
    user = users(:seller)
    visit seller_login_path
    fill_in "E-mail", with: user.email_address
    fill_in "Senha", with: "password"
    click_button "Entrar"
    assert_current_path seller_root_path
  end
end
