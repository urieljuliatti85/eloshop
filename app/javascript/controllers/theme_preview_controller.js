import { Controller } from "@hotwired/stimulus"

// Pré-visualização do tema da vitrine, toda no navegador: lê as escolhas do
// formulário e reescreve as variáveis CSS e os blocos da maquete. Os valores
// vêm do catálogo fechado de SellerTheme; o servidor revalida tudo ao salvar.
export default class extends Controller {
  static targets = [
    "stage", "cover", "grid", "tile", "heroBlock", "block", "sectionList", "section",
    "footerInput", "footerPreview", "aboutInput", "aboutPreview", "noticeInput", "noticePreview",
    "instagramInput", "whatsappInput", "linksPreview", "useCustomColor", "customColor", "contrastHint",
    "palette", "font", "layout", "hero", "corners", "cardStyle"
  ]
  static values = { palettes: Object, fonts: Object, presets: Object, minContrast: Number }

  connect() {
    this.update()
  }

  update() {
    this.applyColors()
    const font = this.fontsValue[this.checked("font")]
    if (font) this.stageTarget.style.setProperty("--atelier-font", font)

    this.applyLayout(this.checked("layout"))
    this.applyHero(this.checked("hero"))
    this.applyShape(this.checked("corners"), this.checked("cardStyle"))
    this.applySections()
    this.applyTexts()
  }

  applyPreset(event) {
    const preset = this.presetsValue[event.currentTarget.dataset.preset]
    if (!preset) return

    this.check("palette", preset.palette)
    this.check("font", preset.font)
    this.check("layout", preset.layout)
    this.check("hero", preset.hero)
    this.check("corners", preset.corners)
    this.check("cardStyle", preset.card_style)
    this.update()
  }

  applyColors() {
    const style = this.stageTarget.style
    const custom = this.useCustomColorTarget.checked
    const color = this.customColorTarget.value
    this.customColorTarget.disabled = !custom

    if (custom) {
      style.setProperty("--atelier-from", `color-mix(in srgb, ${color} 55%, black)`)
      style.setProperty("--atelier-to", color)
      style.setProperty("--atelier-glow", `color-mix(in srgb, ${color} 70%, white)`)
      style.setProperty("--atelier-soft", `color-mix(in srgb, ${color} 25%, white)`)
      style.setProperty("--atelier-accent", color)
      const ratio = this.contrast(color)
      this.contrastHintTarget.textContent = ratio >= this.minContrastValue
        ? `Contraste ${ratio.toFixed(1)}:1 — legível.`
        : `Contraste ${ratio.toFixed(1)}:1 — claro demais, o servidor vai recusar. Escolha uma cor mais escura.`
      return
    }

    this.contrastHintTarget.textContent = ""
    const palette = this.palettesValue[this.checked("palette")]
    if (!palette) return
    style.setProperty("--atelier-from", palette.from)
    style.setProperty("--atelier-to", palette.to)
    style.setProperty("--atelier-glow", palette.glow)
    style.setProperty("--atelier-soft", palette.soft)
    style.setProperty("--atelier-accent", palette.accent)
  }

  applyLayout(layout) {
    const columns = layout === "ampla" ? 3 : 4
    this.gridTarget.style.gridTemplateColumns = `repeat(${columns}, minmax(0, 1fr))`
    this.tileTargets.forEach((tile, index) => {
      const featured = layout === "destaque" && index === 0
      tile.style.gridColumn = featured ? "span 2" : ""
      tile.style.gridRow = featured ? "span 2" : ""
    })
  }

  // "Compacto" esconde a foto de capa e usa só o degradê da paleta.
  applyHero(hero) {
    this.coverTargets.forEach((cover) => { cover.hidden = hero === "compacto" })
  }

  applyShape(corners, cardStyle) {
    const radius = { retos: "0", suaves: "1rem", arredondados: "1.75rem" }[corners] || "1rem"
    this.heroBlockTarget.style.borderRadius = radius
    this.tileTargets.forEach((tile) => {
      tile.style.borderRadius = corners === "retos" ? "0" : corners === "arredondados" ? "1rem" : "0.5rem"
      tile.style.border = cardStyle === "borda" ? "1px solid #d6d3d1" : ""
      tile.style.boxShadow = cardStyle === "sombra" ? "0 4px 14px rgba(0,0,0,0.12)" : ""
    })
  }

  // A ordem das linhas da lista é a ordem dos blocos; "sobre" e "rodapé"
  // só aparecem marcados e com conteúdo, como na vitrine real.
  applySections() {
    const keys = this.sectionTargets.map((input) => ({ key: input.value, on: input.type === "hidden" || input.checked }))
    const hasContent = { catalog: true, about: this.aboutInputTarget.value.trim() !== "", footer: this.footerInputTarget.value.trim() !== "" }
    this.blockTargets.forEach((block) => {
      const position = keys.findIndex((entry) => entry.key === block.dataset.section)
      block.style.order = position
      block.hidden = !(keys[position]?.on && hasContent[block.dataset.section])
    })
  }

  applyTexts() {
    this.aboutPreviewTarget.textContent = this.aboutInputTarget.value
    this.footerPreviewTarget.textContent = this.footerInputTarget.value

    const notice = this.noticeInputTarget.value.trim()
    this.noticePreviewTarget.textContent = notice
    this.noticePreviewTarget.hidden = notice === ""

    const links = []
    if (this.instagramInputTarget.value.trim()) links.push("Instagram")
    if (this.whatsappInputTarget.value.trim()) links.push("WhatsApp")
    this.linksPreviewTarget.textContent = links.join(" · ")
    this.linksPreviewTarget.hidden = links.length === 0
  }

  moveUp(event) {
    const item = event.currentTarget.closest("li")
    if (item.previousElementSibling) item.previousElementSibling.before(item)
    this.applySections()
  }

  moveDown(event) {
    const item = event.currentTarget.closest("li")
    if (item.nextElementSibling) item.nextElementSibling.after(item)
    this.applySections()
  }

  // Razão de contraste WCAG contra o branco (a mesma conta do servidor).
  contrast(hex) {
    const channels = [1, 3, 5].map((i) => {
      const value = parseInt(hex.slice(i, i + 2), 16) / 255
      return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4
    })
    const luminance = 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    return 1.05 / (luminance + 0.05)
  }

  checked(name) {
    return this[`${name}Targets`].find((input) => input.checked)?.value
  }

  check(name, value) {
    const input = this[`${name}Targets`].find((candidate) => candidate.value === value)
    if (input) input.checked = true
  }
}
