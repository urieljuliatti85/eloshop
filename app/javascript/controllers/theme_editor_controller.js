import { Controller } from "@hotwired/stimulus"

// Editor de tema da vitrine. O preview é a própria vitrine num iframe: a cada
// mudança no formulário o rascunho vai por query string para
// `/painel/atelie/tema/preview`, que renderiza a página real em memória (nada
// é gravado). Arquivos não vão no rascunho: o preview mostra os já salvos.
export default class extends Controller {
  static targets = ["form", "tab", "panel", "stage", "frame", "viewport", "status", "device", "dirty", "useCustomColor", "customColor", "contrastHint"]
  static values = { previewUrl: String, presets: Object, minContrast: Number, initialTab: String }
  static classes = ["open"]

  connect() {
    this.device = "phone"
    this.timer = null
    this.resize = () => this.fit()
    window.addEventListener("resize", this.resize)
    this.frameTarget.addEventListener("load", () => this.loaded())
    this.syncColor()
    this.refresh()
    this.fit()
  }

  disconnect() {
    window.removeEventListener("resize", this.resize)
    clearTimeout(this.timer)
  }

  // --- formulário -------------------------------------------------------

  changed() {
    this.dirtyTarget.hidden = false
    this.syncColor()
    this.schedule()
  }

  applyPreset(event) {
    const preset = this.presetsValue[event.currentTarget.dataset.preset]
    if (!preset) return

    this.check("theme_palette", preset.palette)
    this.check("theme_font", preset.font)
    this.check("theme_layout", preset.layout)
    this.check("theme_hero", preset.hero)
    this.check("theme_corners", preset.corners)
    this.check("theme_card_style", preset.card_style)
    this.useCustomColorTarget.checked = false
    this.changed()
  }

  check(attribute, value) {
    const input = this.formTarget.querySelector(`input[name="seller[${attribute}]"][value="${value}"]`)
    if (input) input.checked = true
  }

  moveUp(event) {
    const item = event.currentTarget.closest("li")
    if (item.previousElementSibling) item.previousElementSibling.before(item)
    this.changed()
  }

  moveDown(event) {
    const item = event.currentTarget.closest("li")
    if (item.nextElementSibling) item.nextElementSibling.after(item)
    this.changed()
  }

  // Cor própria: o input só vale com o checkbox ligado; mostra o contraste
  // (a mesma conta do servidor, que é quem recusa de fato).
  syncColor() {
    const custom = this.useCustomColorTarget.checked
    this.customColorTarget.disabled = !custom
    if (!custom) {
      this.contrastHintTarget.textContent = ""
      return
    }
    const ratio = this.contrast(this.customColorTarget.value)
    this.contrastHintTarget.textContent = ratio >= this.minContrastValue
      ? `Contraste ${ratio.toFixed(1)}:1 — legível.`
      : `Contraste ${ratio.toFixed(1)}:1 — claro demais, será recusada ao salvar.`
  }

  contrast(hex) {
    const channels = [1, 3, 5].map((i) => {
      const value = parseInt(hex.slice(i, i + 2), 16) / 255
      return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4
    })
    const luminance = 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    return 1.05 / (luminance + 0.05)
  }

  // --- abas -------------------------------------------------------------

  selectTab(event) {
    this.showTab(event.currentTarget.dataset.key)
  }

  showTab(key, focus = false) {
    this.tabTargets.forEach((tab) => {
      const selected = tab.dataset.key === key
      tab.setAttribute("aria-selected", selected)
      tab.tabIndex = selected ? 0 : -1
      if (selected && focus) tab.focus()
      // A faixa de abas rola no celular: a aba escolhida precisa ficar à vista.
      if (selected) tab.scrollIntoView({ inline: "center", block: "nearest", behavior: "smooth" })
    })
    this.panelTargets.forEach((panel) => { panel.hidden = panel.dataset.key !== key })
  }

  tabKey(event) {
    const step = { ArrowRight: 1, ArrowLeft: -1 }[event.key]
    if (!step) return
    event.preventDefault()
    const index = this.tabTargets.indexOf(event.currentTarget)
    const next = this.tabTargets[(index + step + this.tabTargets.length) % this.tabTargets.length]
    this.showTab(next.dataset.key, true)
  }

  // --- preview ----------------------------------------------------------

  schedule() {
    clearTimeout(this.timer)
    this.statusTarget.textContent = "Atualizando…"
    this.timer = setTimeout(() => this.refresh(), 450)
  }

  refresh() {
    const params = new URLSearchParams()
    for (const [name, value] of new FormData(this.formTarget)) {
      if (typeof value === "string" && (name.startsWith("seller[") || name === "use_custom_color")) params.append(name, value)
    }
    this.scrollY = this.frameTarget.contentWindow?.scrollY || 0
    this.statusTarget.textContent = "Atualizando…"
    this.frameTarget.src = `${this.previewUrlValue}?${params}`
  }

  loaded() {
    this.frameTarget.contentWindow?.scrollTo(0, this.scrollY || 0)
    this.statusTarget.textContent = "Atualizado"
  }

  setDevice(event) {
    this.device = event.currentTarget.dataset.device
    this.deviceTargets.forEach((button) => button.setAttribute("aria-pressed", button.dataset.device === this.device))
    this.fit()
  }

  // No celular a folha usa a largura real da tela; no desktop o "celular"
  // tem 390px e o "computador" 1280px reduzidos para caber (transform).
  fit() {
    const box = this.viewportTarget
    const width = box.clientWidth
    const height = box.clientHeight
    if (!width || !height) return

    const wide = window.matchMedia("(min-width: 1024px)").matches
    const logical = !wide ? width : this.device === "desktop" ? 1280 : 390
    const scale = Math.min(1, width / logical)
    const frame = this.frameTarget.style
    frame.width = `${logical}px`
    frame.height = `${height / scale}px`
    frame.transform = `scale(${scale})`
    frame.left = `${Math.max(0, (width - logical * scale) / 2)}px`
  }

  openPreview() {
    this.stageTarget.classList.remove("hidden")
    this.stageTarget.classList.add(...this.openClasses)
    document.body.classList.add("overflow-hidden")
    this.refresh()
    requestAnimationFrame(() => this.fit())
  }

  closePreview() {
    this.stageTarget.classList.remove(...this.openClasses)
    this.stageTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }
}
