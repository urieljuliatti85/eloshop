import { Controller } from "@hotwired/stimulus"

// Pré-visualização do tema da vitrine, toda no navegador: lê as escolhas do
// formulário e reescreve as variáveis CSS da maquete. Os valores vêm do
// catálogo fechado de SellerTheme; o servidor revalida tudo ao salvar.
export default class extends Controller {
  static targets = ["stage", "cover", "grid", "tile", "footerInput", "footerPreview", "palette", "font", "layout", "hero"]
  static values = { palettes: Object, fonts: Object, presets: Object }

  connect() {
    this.update()
  }

  update() {
    const palette = this.palettesValue[this.checked("palette")]
    const font = this.fontsValue[this.checked("font")]

    if (palette) {
      const style = this.stageTarget.style
      style.setProperty("--atelier-from", palette.from)
      style.setProperty("--atelier-to", palette.to)
      style.setProperty("--atelier-glow", palette.glow)
      style.setProperty("--atelier-soft", palette.soft)
      style.setProperty("--atelier-accent", palette.accent)
    }
    if (font) this.stageTarget.style.setProperty("--atelier-font", font)

    this.applyLayout(this.checked("layout"))
    this.applyHero(this.checked("hero"))
    this.footerPreviewTarget.textContent = this.footerInputTarget.value
  }

  applyPreset(event) {
    const preset = this.presetsValue[event.currentTarget.dataset.preset]
    if (!preset) return

    this.check("palette", preset.palette)
    this.check("font", preset.font)
    this.check("layout", preset.layout)
    this.check("hero", preset.hero)
    this.update()
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

  checked(name) {
    return this[`${name}Targets`].find((input) => input.checked)?.value
  }

  check(name, value) {
    const input = this[`${name}Targets`].find((candidate) => candidate.value === value)
    if (input) input.checked = true
  }
}
