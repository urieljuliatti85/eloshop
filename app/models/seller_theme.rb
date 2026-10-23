# Catálogo fechado de opções visuais da vitrine do ateliê. O artesão escolhe
# entre estas chaves; nenhum CSS ou cor livre chega à página, então não há o
# que sanitizar e a vitrine nunca fica ilegível. Os valores viram variáveis
# CSS no servidor (vitrine) e no navegador (pré-visualização do editor).
module SellerTheme
  PALETTES = {
    "terracota" => { label: "Terracota", from: "#7a2410", to: "#df240c", glow: "#f6604c", soft: "#fbbeb6", accent: "#c2300c" },
    "oliva"     => { label: "Oliva",     from: "#2f3a1c", to: "#687c29", glow: "#9bb04a", soft: "#dfe8b8", accent: "#4d5f1c" },
    "oceano"    => { label: "Oceano",    from: "#0b3a4a", to: "#1c7c93", glow: "#4fb3c8", soft: "#c4e8f0", accent: "#0e6479" },
    "ameixa"    => { label: "Ameixa",    from: "#3d1a3f", to: "#8a3a8f", glow: "#c27ac7", soft: "#ecd0ee", accent: "#7a2e80" },
    "grafite"   => { label: "Grafite",   from: "#1f2326", to: "#4b5358", glow: "#8a949a", soft: "#d9dee1", accent: "#333b40" },
    "mostarda"  => { label: "Mostarda",  from: "#4a3505", to: "#8a6206", glow: "#d9a72b", soft: "#f5e3b3", accent: "#7a5604" },
    "floresta"  => { label: "Floresta",  from: "#0f2e22", to: "#1f6b4a", glow: "#4fae84", soft: "#c8ecd9", accent: "#19573c" },
    "vinho"     => { label: "Vinho",     from: "#3b0a1a", to: "#8c1c3c", glow: "#d4567a", soft: "#f5cdd8", accent: "#7d1834" },
    "argila"    => { label: "Argila",    from: "#4a2420", to: "#9a4d45", glow: "#d98c7f", soft: "#f6d9d3", accent: "#8a4038" },
    "indigo"    => { label: "Índigo",    from: "#141a3d", to: "#3a43a0", glow: "#7b84e0", soft: "#d6d9f7", accent: "#333c96" },
    "lavanda"   => { label: "Lavanda",   from: "#2e2450", to: "#6a55b0", glow: "#a594e6", soft: "#e4def9", accent: "#5a46a0" },
    "caramelo"  => { label: "Caramelo",  from: "#3f2412", to: "#8f5426", glow: "#d4935a", soft: "#f4dcc4", accent: "#7e4920" },
    "cacau"     => { label: "Cacau",     from: "#2a1a14", to: "#5e3a2c", glow: "#a0705a", soft: "#ead8cf", accent: "#5a3729" }
  }.freeze

  # Só pilhas de fontes do sistema: a CSP não admite fonte externa.
  FONTS = {
    "moderna"   => { label: "Moderna",   stack: "ui-sans-serif, system-ui, -apple-system, 'Segoe UI', sans-serif" },
    "classica"  => { label: "Clássica",  stack: "Georgia, 'Times New Roman', serif" },
    "artesanal" => { label: "Artesanal", stack: "'Trebuchet MS', ui-rounded, 'Segoe UI', sans-serif" },
    "elegante"  => { label: "Elegante",  stack: "Didot, 'Bodoni 72', 'Bodoni MT', 'Times New Roman', serif" },
    "geometrica" => { label: "Geométrica", stack: "'Avenir Next', Avenir, 'Century Gothic', 'Segoe UI', sans-serif" },
    "humanista" => { label: "Humanista", stack: "Optima, Candara, 'Segoe UI', sans-serif" },
    "maquina"   => { label: "Datilografada", stack: "'American Typewriter', 'Courier New', ui-monospace, monospace" }
  }.freeze

  # Fonte dos títulos (nome do ateliê e das seções). As fontes próprias são
  # servidas pelo app (`app/assets/fonts`, a CSP só admite `font-src 'self'`)
  # e o navegador só baixa a que a página usa. "Igual" repete a do texto.
  HEADING_FONTS = {
    "igual"         => { label: "Igual ao texto" },
    "suave"         => { label: "Suave",         stack: "'Fraunces', Georgia, serif" },
    "revista"       => { label: "Revista",       stack: "'DM Serif Display', Georgia, serif" },
    "manuscrita"    => { label: "Manuscrita",    stack: "'Caveat', 'Trebuchet MS', cursive" },
    "contemporanea" => { label: "Urbana",        stack: "'Space Grotesk', ui-sans-serif, system-ui, sans-serif" }
  }.freeze

  LAYOUTS = {
    "grade"    => "Grade (4 colunas)",
    "ampla"    => "Ampla (3 colunas)",
    "destaque" => "Destaque (a peça mais recente em tamanho grande)"
  }.freeze

  HEROES = {
    "capa"      => "Com capa (foto no topo)",
    "compacto"  => "Compacto (só a cor, sem foto)",
    "dividido"  => "Dividido (foto ao lado do nome)",
    "editorial" => "Editorial (nome grande, foto embaixo)",
    "faixa"     => "Faixa fina (o catálogo logo no início)"
  }.freeze

  CORNERS = {
    "retos"        => "Retos",
    "suaves"       => "Suaves",
    "arredondados" => "Bem arredondados"
  }.freeze

  CARD_STYLES = {
    "limpo"  => "Limpo (sem moldura)",
    "borda"  => "Com borda",
    "sombra" => "Com sombra",
    "fundo"  => "Fundo (tom da paleta)"
  }.freeze

  # O fundo escuro mistura o início do degradê da paleta com quase preto.
  DARK_BASE = "#0c0a09"
  DARK_FROM_SHARE = 35

  # Fundo da página inteira da vitrine. As texturas são SVG embutido (data
  # URI, permitido pela CSP em `img-src`), em tom neutro e opacidade baixa
  # para não competir com as fotos. O escuro (`dark: true`) é a paleta quase
  # preta: a vitrine troca as cores do texto pela classe `atelier-dark` (ver
  # application.css), e o card de peça, que é o mesmo do resto da loja,
  # mantém a foto e os botões claros.
  BACKGROUNDS = {
    "branco" => { label: "Branco" },
    "papel"  => { label: "Papel", color: "#faf6ee",
                  texture: "<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='g'>" \
                           "<feTurbulence type='fractalNoise' baseFrequency='.8' numOctaves='3' stitchTiles='stitch'/>" \
                           "<feColorMatrix values='0 0 0 0 .4 0 0 0 0 .3 0 0 0 0 .2 0 0 0 .09 0'/></filter>" \
                           "<rect width='100%' height='100%' filter='url(#g)'/></svg>" },
    "linho"  => { label: "Linho", color: "#f6f1e8",
                  texture: "<svg xmlns='http://www.w3.org/2000/svg' width='6' height='6'>" \
                           "<path d='M0 .5h6M0 3.5h6' stroke='#6b4e2e' stroke-opacity='.07'/>" \
                           "<path d='M.5 0v6M3.5 0v6' stroke='#6b4e2e' stroke-opacity='.05'/></svg>" },
    "tom"    => { label: "Tom da paleta", color: "color-mix(in srgb, var(--atelier-soft) 35%, white)" },
    "escuro" => { label: "Escuro", color: "color-mix(in srgb, var(--atelier-from) #{DARK_FROM_SHARE}%, #{DARK_BASE})", dark: true }
  }.freeze

  # Ornamento entre o topo e as seções, desenhado como máscara: a forma vem do
  # SVG e a cor, da paleta (`--atelier-accent`). `height` é a altura da faixa.
  ORNAMENTS = {
    "nenhum"  => { label: "Nenhum" },
    "chita"   => { label: "Chita", height: 28,
                   svg: "<svg xmlns='http://www.w3.org/2000/svg' width='56' height='28'><g transform='translate(14 14)'>" \
                        "<circle r='2.2'/><circle cy='-6' r='3.1'/><circle cx='5.7' cy='-1.9' r='3.1'/><circle cx='3.5' cy='4.9' r='3.1'/>" \
                        "<circle cx='-3.5' cy='4.9' r='3.1'/><circle cx='-5.7' cy='-1.9' r='3.1'/></g>" \
                        "<ellipse cx='36' cy='10' rx='5' ry='2.2' transform='rotate(-30 36 10)'/>" \
                        "<ellipse cx='40' cy='18' rx='5' ry='2.2' transform='rotate(25 40 18)'/><circle cx='50' cy='14' r='1.6'/></svg>" },
    "renda"   => { label: "Renda", height: 16,
                   svg: "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='16'><path fill-rule='evenodd' " \
                        "d='M0 0h24v4a12 12 0 0 1-24 0zM9.5 8a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0-5 0zM2 2a1 1 0 1 0 2 0a1 1 0 1 0-2 0z'/></svg>" },
    "costura" => { label: "Costura", height: 12,
                   svg: "<svg xmlns='http://www.w3.org/2000/svg' width='22' height='12'><rect x='1' y='5' width='10' height='2' rx='1'/>" \
                        "<path d='M14 3l5 6M19 3l-5 6' stroke='black' stroke-width='1.6' stroke-linecap='round'/></svg>" },
    "ondas"   => { label: "Ondas", height: 12,
                   svg: "<svg xmlns='http://www.w3.org/2000/svg' width='32' height='12'>" \
                        "<path d='M0 6q8-6 16 0t16 0' fill='none' stroke='black' stroke-width='2'/></svg>" },
    "folhas"  => { label: "Folhas", height: 16,
                   svg: "<svg xmlns='http://www.w3.org/2000/svg' width='40' height='16'><path d='M0 8h40' stroke='black' stroke-width='1.2'/>" \
                        "<path d='M10 8C12 3 17 2 21 3C19 7 15 8 10 8Z'/><path d='M30 8C28 13 23 14 19 13C21 9 25 8 30 8Z'/></svg>" },
    "trancado" => { label: "Trançado", height: 12,
                    svg: "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='12'>" \
                         "<path d='M0 2h6l2 3H2zM8 7h6l2 3H10z'/><path d='M8 2h6l-2 3H6zM0 7h6l-2 3H-2z' opacity='.5'/></svg>" }
  }.freeze

  # Proporção da foto nos cards de peça.
  IMAGE_RATIOS = {
    "quadrada" => "Quadrada",
    "retrato"  => "Retrato (vertical)",
    "paisagem" => "Paisagem (horizontal)"
  }.freeze

  # Seções reordenáveis da vitrine. O catálogo é a razão de a página existir:
  # nunca some. "Sobre" e "rodapé" só aparecem se houver conteúdo.
  SECTIONS = { "catalog" => "Catálogo", "about" => "Sobre o ateliê", "footer" => "Mensagem do rodapé" }.freeze
  DEFAULT_SECTIONS = %w[catalog about footer].freeze

  # Cor própria: o texto de destaque cai sobre fundo branco, então exige o
  # contraste mínimo AA (4,5:1) da WCAG para texto normal.
  MIN_ACCENT_CONTRAST = 4.5

  DEFAULTS = { palette: "terracota", font: "moderna", layout: "grade", hero: "capa",
               background: "branco", ornament: "nenhum", image_ratio: "quadrada", heading_font: "igual" }.freeze

  # Os temas que vieram antes do fundo, do ornamento e da fonte de título os
  # mantêm no padrão.
  PLAIN_PAGE = DEFAULTS.slice(:background, :ornament, :image_ratio, :heading_font).freeze

  PRESETS = {
    # Primeiro os temas que usam fundo, topo, ornamento e foto, não só cor e
    # fonte: são os que mais mudam a vitrine.
    "ceramica"    => { label: "Cerâmica",    palette: "argila",   font: "classica",  layout: "ampla",    hero: "dividido",  corners: "suaves",       card_style: "limpo",
                       background: "tom",    ornament: "nenhum",  image_ratio: "retrato", heading_font: "suave" },
    "caderno"     => { label: "Caderno de ateliê", palette: "cacau", font: "maquina", layout: "grade",   hero: "editorial", corners: "retos",        card_style: "borda",
                       background: "papel",  ornament: "costura", image_ratio: "quadrada", heading_font: "manuscrita" },
    "galeria"     => { label: "Galeria",     palette: "grafite",  font: "elegante",  layout: "ampla",    hero: "faixa",     corners: "retos",        card_style: "limpo",
                       background: "branco", ornament: "nenhum",  image_ratio: "retrato", heading_font: "revista" },
    "chita"       => { label: "Chita",       palette: "terracota", font: "artesanal", layout: "grade",   hero: "capa",      corners: "arredondados", card_style: "borda",
                       background: "papel",  ornament: "chita",   image_ratio: "quadrada", heading_font: "manuscrita" },
    "litoral"     => { label: "Litoral",     palette: "oceano",   font: "humanista", layout: "destaque", hero: "dividido",  corners: "suaves",       card_style: "sombra",
                       background: "linho",  ornament: "ondas",   image_ratio: "paisagem", heading_font: "contemporanea" },
    "renda"       => { label: "Renda",       palette: "lavanda",  font: "elegante",  layout: "destaque", hero: "editorial", corners: "arredondados", card_style: "fundo",
                       background: "tom",    ornament: "renda",   image_ratio: "retrato", heading_font: "revista" },
    "cestaria"    => { label: "Cestaria",    palette: "caramelo", font: "geometrica", layout: "grade",  hero: "faixa",     corners: "retos",        card_style: "borda",
                       background: "linho",  ornament: "trancado", image_ratio: "quadrada", heading_font: "contemporanea" },
    "horta"       => { label: "Horta",       palette: "oliva",    font: "humanista", layout: "destaque", hero: "dividido",  corners: "arredondados", card_style: "fundo",
                       background: "tom",    ornament: "folhas",  image_ratio: "paisagem", heading_font: "manuscrita" },
    "carta"       => { label: "Carta de amor", palette: "vinho",  font: "classica",  layout: "grade",    hero: "capa",      corners: "arredondados", card_style: "sombra",
                       background: "papel",  ornament: "renda",   image_ratio: "retrato", heading_font: "revista" },
    "bordado"     => { label: "Bordado",     palette: "ameixa",   font: "artesanal", layout: "ampla",    hero: "compacto",  corners: "suaves",       card_style: "fundo",
                       background: "tom",    ornament: "costura", image_ratio: "quadrada", heading_font: "manuscrita" },
    # Temas de fundo escuro.
    "noite"       => { label: "Noite de feira", palette: "mostarda", font: "moderna", layout: "grade",  hero: "capa",      corners: "suaves",       card_style: "fundo",
                       background: "escuro", ornament: "costura", image_ratio: "quadrada", heading_font: "contemporanea" },
    "brasa"       => { label: "Brasa",       palette: "terracota", font: "humanista", layout: "ampla",  hero: "dividido",  corners: "arredondados", card_style: "limpo",
                       background: "escuro", ornament: "nenhum",  image_ratio: "retrato", heading_font: "suave" },
    "mata"        => { label: "Mata",        palette: "floresta", font: "humanista", layout: "ampla",    hero: "editorial", corners: "suaves",       card_style: "limpo",
                       background: "escuro", ornament: "folhas",  image_ratio: "retrato", heading_font: "suave" },
    "vitral"      => { label: "Vitral",      palette: "indigo",   font: "elegante",  layout: "destaque", hero: "faixa",     corners: "retos",        card_style: "sombra",
                       background: "escuro", ornament: "nenhum",  image_ratio: "quadrada", heading_font: "revista" },
    # Temas de cor e fonte, sobre a página branca de sempre.
    "rustico"     => { label: "Rústico",     palette: "oliva",   font: "classica",  layout: "grade",    hero: "capa",     corners: "suaves",       card_style: "limpo" }.merge(PLAIN_PAGE),
    "minimalista" => { label: "Minimalista", palette: "grafite", font: "moderna",   layout: "ampla",    hero: "compacto", corners: "retos",        card_style: "borda" }.merge(PLAIN_PAGE),
    "boho"        => { label: "Boho",        palette: "terracota", font: "artesanal", layout: "destaque", hero: "capa",     corners: "arredondados", card_style: "sombra" }.merge(PLAIN_PAGE),
    "solar"       => { label: "Solar",       palette: "mostarda", font: "geometrica", layout: "destaque", hero: "compacto", corners: "arredondados", card_style: "fundo" }.merge(PLAIN_PAGE)
  }.freeze

  # Variáveis CSS da vitrine. Só valores do catálogo acima (ou um hex já
  # validado por `contrast_ratio`) entram aqui. Com cor própria, as demais
  # cores do topo saem dela por `color-mix`, sem tabela por cor.
  #
  # Sobre o fundo escuro, o destaque que aparece como texto ou ornamento na
  # página (`--atelier-accent-on-page`) passa a ser o tom claro da paleta, e
  # o card com fundo (`--atelier-card`) escurece junto.
  def self.css_variables(palette:, font:, accent_color: nil, heading_font: nil, background: nil)
    colors = PALETTES.fetch(palette, PALETTES.fetch(DEFAULTS[:palette]))
    stack = FONTS.fetch(font, FONTS.fetch(DEFAULTS[:font]))[:stack]
    heading = HEADING_FONTS.dig(heading_font, :stack) || "var(--atelier-font)"
    dark = dark?(background)
    if accent_color&.match?(HEX_COLOR)
      colors = {
        from: "color-mix(in srgb, #{accent_color} 55%, black)", to: accent_color,
        glow: "color-mix(in srgb, #{accent_color} 70%, white)", soft: "color-mix(in srgb, #{accent_color} 25%, white)",
        accent: accent_color
      }
    end
    on_page = dark ? "var(--atelier-soft)" : "var(--atelier-accent)"
    card = dark ? "color-mix(in srgb, var(--atelier-to) 22%, #1c1917)" : "color-mix(in srgb, var(--atelier-soft) 45%, white)"
    "--atelier-from:#{colors[:from]};--atelier-to:#{colors[:to]};--atelier-glow:#{colors[:glow]};" \
      "--atelier-soft:#{colors[:soft]};--atelier-accent:#{colors[:accent]};--atelier-font:#{stack};" \
      "--atelier-heading-font:#{heading};--atelier-accent-on-page:#{on_page};--atelier-card:#{card}"
  end

  def self.dark?(background)
    BACKGROUNDS.dig(background, :dark) == true
  end

  HEX_COLOR = /\A#\h{6}\z/

  # Estilo da camada de fundo da página, ou nil para o branco (sem camada).
  def self.page_background_style(background)
    choice = BACKGROUNDS[background]
    return unless choice&.dig(:color)

    style = "background-color:#{choice[:color]}"
    style += ";background-image:#{svg_url(choice[:texture])}" if choice[:texture]
    style
  end

  # Estilo da faixa de ornamento, ou nil para "nenhum".
  def self.ornament_style(ornament)
    choice = ORNAMENTS[ornament]
    return unless choice&.dig(:svg)

    mask = "#{svg_url(choice[:svg])} repeat-x center / auto 100%"
    "height:#{choice[:height]}px;-webkit-mask:#{mask};mask:#{mask}"
  end

  # SVG do catálogo acima como data URI. Codificado por inteiro, então não há
  # aspas nem parênteses que fechem o `url()` antes da hora.
  def self.svg_url(svg)
    "url(data:image/svg+xml,#{ERB::Util.url_encode(svg)})"
  end

  # Razão de contraste WCAG entre duas cores (por padrão, contra o branco).
  def self.contrast_ratio(hex, other = "#ffffff")
    lighter, darker = [ luminance(hex), luminance(other) ].minmax.reverse
    (lighter + 0.05) / (darker + 0.05)
  end

  def self.luminance(hex)
    channels = hex.delete("#").scan(/../).map do |pair|
      value = pair.to_i(16) / 255.0
      value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
    end
    0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
  end
end
