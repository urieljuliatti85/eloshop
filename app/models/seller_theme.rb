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

  LAYOUTS = {
    "grade"    => "Grade (4 colunas)",
    "ampla"    => "Ampla (3 colunas)",
    "destaque" => "Destaque (a peça mais recente em tamanho grande)"
  }.freeze

  HEROES = {
    "capa"     => "Com capa (foto no topo)",
    "compacto" => "Compacto (só a cor, sem foto)"
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

  # Seções reordenáveis da vitrine. O catálogo é a razão de a página existir:
  # nunca some. "Sobre" e "rodapé" só aparecem se houver conteúdo.
  SECTIONS = { "catalog" => "Catálogo", "about" => "Sobre o ateliê", "footer" => "Mensagem do rodapé" }.freeze
  DEFAULT_SECTIONS = %w[catalog about footer].freeze

  # Cor própria: o texto de destaque cai sobre fundo branco, então exige o
  # contraste mínimo AA (4,5:1) da WCAG para texto normal.
  MIN_ACCENT_CONTRAST = 4.5

  DEFAULTS = { palette: "terracota", font: "moderna", layout: "grade", hero: "capa" }.freeze

  PRESETS = {
    "rustico"     => { label: "Rústico",     palette: "oliva",   font: "classica",  layout: "grade",    hero: "capa",     corners: "suaves",       card_style: "limpo" },
    "minimalista" => { label: "Minimalista", palette: "grafite", font: "moderna",   layout: "ampla",    hero: "compacto", corners: "retos",        card_style: "borda" },
    "boho"        => { label: "Boho",        palette: "terracota", font: "artesanal", layout: "destaque", hero: "capa",     corners: "arredondados", card_style: "sombra" },
    "marinho"     => { label: "Marinho",     palette: "oceano",  font: "moderna",   layout: "grade",    hero: "capa",     corners: "suaves",       card_style: "borda" },
    "floral"      => { label: "Floral",      palette: "ameixa",  font: "classica",  layout: "destaque", hero: "compacto", corners: "arredondados", card_style: "limpo" },
    "cafe"        => { label: "Café",        palette: "cacau",   font: "maquina",   layout: "grade",    hero: "capa",     corners: "retos",        card_style: "borda" },
    "campo"       => { label: "Campo",       palette: "floresta", font: "humanista", layout: "ampla",   hero: "capa",     corners: "suaves",       card_style: "limpo" },
    "solar"       => { label: "Solar",       palette: "mostarda", font: "geometrica", layout: "destaque", hero: "compacto", corners: "arredondados", card_style: "fundo" },
    "noturno"     => { label: "Noturno",     palette: "indigo",  font: "elegante",  layout: "ampla",    hero: "capa",     corners: "retos",        card_style: "sombra" },
    "romantico"   => { label: "Romântico",   palette: "argila",  font: "elegante",  layout: "grade",    hero: "capa",     corners: "arredondados", card_style: "limpo" },
    "provence"    => { label: "Provence",    palette: "lavanda", font: "humanista", layout: "destaque", hero: "compacto", corners: "suaves",       card_style: "fundo" },
    "vinhedo"     => { label: "Vinhedo",     palette: "vinho",   font: "classica",  layout: "ampla",    hero: "capa",     corners: "suaves",       card_style: "sombra" },
    "couro"       => { label: "Couro",       palette: "caramelo", font: "geometrica", layout: "grade",  hero: "compacto", corners: "retos",        card_style: "borda" }
  }.freeze

  # Variáveis CSS da vitrine. Só valores do catálogo acima (ou um hex já
  # validado por `contrast_ratio`) entram aqui. Com cor própria, as demais
  # cores do topo saem dela por `color-mix`, sem tabela por cor.
  def self.css_variables(palette:, font:, accent_color: nil)
    colors = PALETTES.fetch(palette, PALETTES.fetch(DEFAULTS[:palette]))
    stack = FONTS.fetch(font, FONTS.fetch(DEFAULTS[:font]))[:stack]
    if accent_color&.match?(HEX_COLOR)
      colors = {
        from: "color-mix(in srgb, #{accent_color} 55%, black)", to: accent_color,
        glow: "color-mix(in srgb, #{accent_color} 70%, white)", soft: "color-mix(in srgb, #{accent_color} 25%, white)",
        accent: accent_color
      }
    end
    "--atelier-from:#{colors[:from]};--atelier-to:#{colors[:to]};--atelier-glow:#{colors[:glow]};" \
      "--atelier-soft:#{colors[:soft]};--atelier-accent:#{colors[:accent]};--atelier-font:#{stack}"
  end

  HEX_COLOR = /\A#\h{6}\z/

  # Razão de contraste WCAG entre a cor e o branco.
  def self.contrast_ratio(hex)
    channels = hex.delete("#").scan(/../).map do |pair|
      value = pair.to_i(16) / 255.0
      value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
    end
    luminance = 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    1.05 / (luminance + 0.05)
  end
end
