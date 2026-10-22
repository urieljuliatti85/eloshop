import { Controller } from "@hotwired/stimulus"

// Editor de tema da vitrine. O preview é a própria vitrine num iframe: a cada
// mudança no formulário o rascunho vai por query string para
// `/painel/atelie/tema/preview`, que renderiza a página real em memória (nada
// é gravado). Arquivos não vão no rascunho: o preview mostra os já salvos.
export default class extends Controller {
  static targets = ["form", "tab", "panel", "stage", "frame", "viewport", "status", "device", "dirty", "closeButton", "expandButton", "imageNote", "preset", "useCustomColor", "customColor", "contrastHint"]
  static values = { previewUrl: String, presets: Object, minContrast: Number, initialTab: String, maxImageBytes: Number, imageTypes: Array }
  static classes = ["open"]

  connect() {
    this.device = "phone"
    this.timer = null
    this.dirty = false
    this.leaving = false
    this.keydown = (event) => { if (event.key === "Escape" && this.sheetOpen) this.closePreview() }
    this.beforeUnload = (event) => { if (this.dirty && !this.leaving) event.preventDefault() }
    // O painel navega com Turbo: clicar no menu troca de página sem disparar
    // `beforeunload`, e o rascunho sumia sem aviso.
    this.beforeVisit = (event) => {
      if (!this.dirty || this.leaving) return
      if (window.confirm("Sair sem salvar? As alterações do tema serão perdidas.")) this.leaving = true
      else event.preventDefault()
    }
    document.addEventListener("keydown", this.keydown)
    window.addEventListener("beforeunload", this.beforeUnload)
    document.addEventListener("turbo:before-visit", this.beforeVisit)
    this.resize = () => this.fit()
    window.addEventListener("resize", this.resize)
    this.frameTarget.addEventListener("load", () => this.loaded())
    // Um layout oculto (ou redimensionado) só ganha tamanho depois do connect.
    this.observer = new ResizeObserver(() => this.fit())
    this.observer.observe(this.viewportTarget)
    this.stageClass = this.stageTarget.className
    this.syncColor()
    this.syncPresets()
    this.refresh()
    this.fit()
  }

  disconnect() {
    this.observer?.disconnect()
    window.removeEventListener("resize", this.resize)
    window.removeEventListener("beforeunload", this.beforeUnload)
    document.removeEventListener("turbo:before-visit", this.beforeVisit)
    document.removeEventListener("keydown", this.keydown)
    document.body.classList.remove("overflow-hidden")
    clearTimeout(this.timer)
  }

  // --- formulário -------------------------------------------------------

  changed(event) {
    this.dirty = true
    this.dirtyTarget.hidden = false
    this.syncColor()
    this.syncPresets()
    this.count(event?.target)
    this.schedule()
  }

  // Salvar não é "sair sem salvar": o aviso do navegador não deve aparecer.
  submitted() {
    this.leaving = true
  }

  // Descartar apaga o rascunho; com alterações pendentes, confirma antes.
  discard(event) {
    if (this.dirty && !window.confirm("Descartar as alterações não salvas?")) event.preventDefault()
    else this.leaving = true
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

  // Marca o tema pronto que coincide com o formulário (nenhum, se algo foi
  // ajustado depois de aplicar ou se há cor própria).
  syncPresets() {
    const value = (attribute) => this.formTarget.querySelector(`input[name="seller[${attribute}]"]:checked`)?.value
    const current = {
      palette: value("theme_palette"), font: value("theme_font"), layout: value("theme_layout"),
      hero: value("theme_hero"), corners: value("theme_corners"), card_style: value("theme_card_style")
    }
    const custom = this.useCustomColorTarget.checked
    this.presetTargets.forEach((button) => {
      const preset = this.presetsValue[button.dataset.preset]
      const match = !custom && Object.keys(current).every((key) => preset[key] === current[key])
      button.setAttribute("aria-pressed", match)
    })
  }

  moveUp(event) {
    const item = event.currentTarget.closest("li")
    if (item.previousElementSibling) item.previousElementSibling.before(item)
    this.moved(item, "up")
  }

  moveDown(event) {
    const item = event.currentTarget.closest("li")
    if (item.nextElementSibling) item.nextElementSibling.after(item)
    this.moved(item, "down")
  }

  // Seta sem destino fica desabilitada; se foi a que recebeu o clique, o foco
  // passa para a outra seta do mesmo item, em vez de se perder.
  moved(item, direction) {
    const items = [...item.parentElement.children]
    items.forEach((li, index) => {
      li.querySelector("[data-direction=up]").disabled = index === 0
      li.querySelector("[data-direction=down]").disabled = index === items.length - 1
    })
    const pressed = item.querySelector(`[data-direction=${direction}]`)
    const other = item.querySelector(`[data-direction=${direction === "up" ? "down" : "up"}]`)
    ;(pressed.disabled ? other : pressed).focus()
    this.changed()
  }

  // --- imagens e textos -------------------------------------------------

  // O arquivo só sobe ao salvar: aqui mostra uma miniatura local e recusa
  // tipo/tamanho fora do limite antes do envio (o servidor valida de novo).
  pickImage(event) {
    const input = event.currentTarget
    const field = input.closest("[data-image-field]")
    const picked = field.querySelector("[data-role=picked]")
    const error = field.querySelector("[data-role=image-error]")
    const file = input.files[0]

    let message = ""
    if (file && !this.imageTypesValue.includes(file.type)) message = "Formato não aceito. Use PNG, JPEG ou WEBP."
    else if (file && file.size > this.maxImageBytesValue) message = `Arquivo de ${(file.size / 1048576).toFixed(1).replace(".", ",")} MB: o limite é ${Math.round(this.maxImageBytesValue / 1048576)} MB.`
    input.setCustomValidity(message)
    error.textContent = message
    error.hidden = !message
    picked.hidden = true

    if (file && !message) {
      const reader = new FileReader()
      reader.onload = () => {
        picked.querySelector("img").src = reader.result
        picked.hidden = false
      }
      reader.readAsDataURL(file)
    }
    this.imageNoteTarget.hidden = ![...this.formTarget.querySelectorAll("input[type=file]")].some((each) => each.files.length)
  }

  // Um campo inválido numa aba oculta não recebe foco e o envio falha calado:
  // abre a aba dele antes de o navegador mostrar a mensagem.
  revealInvalid(event) {
    const panel = event.currentTarget.closest("[role=tabpanel]")
    if (panel?.hidden) this.showTab(panel.dataset.key)
  }

  count(input) {
    const counter = input?.closest("[data-counted]")?.querySelector("[data-role=count]")
    if (counter) counter.textContent = `${input.value.length}/${input.maxLength}`
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
    })
    this.panelTargets.forEach((panel) => { panel.hidden = panel.dataset.key !== key })
  }

  tabKey(event) {
    const last = this.tabTargets.length - 1
    const index = this.tabTargets.indexOf(event.currentTarget)
    const target = {
      ArrowRight: index === last ? 0 : index + 1,
      ArrowDown: index === last ? 0 : index + 1,
      ArrowLeft: index === 0 ? last : index - 1,
      ArrowUp: index === 0 ? last : index - 1,
      Home: 0,
      End: last
    }[event.key]
    if (target === undefined) return
    event.preventDefault()
    this.showTab(this.tabTargets[target].dataset.key, true)
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

  // No celular o preview é uma folha em tela cheia: vira diálogo (foco entra
  // em "Fechar", Esc fecha, e o foco volta ao botão que a abriu).
  // No desktop, "Ampliar" abre a mesma folha: a coluna da prévia é estreita
  // demais para julgar o layout de computador. As classes da coluna são
  // trocadas inteiras (as `lg:` dela venceriam o `fixed` da folha).
  openPreview(event) {
    this.opener = event.currentTarget
    this.sheetOpen = true
    this.stageTarget.className = this.openClasses.join(" ")
    this.closeButtonTarget.hidden = false
    this.expandButtonTarget.hidden = true
    this.stageTarget.setAttribute("role", "dialog")
    this.stageTarget.setAttribute("aria-modal", "true")
    document.body.classList.add("overflow-hidden")
    this.refresh()
    this.closeButtonTarget.focus()
    requestAnimationFrame(() => this.fit())
  }

  closePreview() {
    this.sheetOpen = false
    this.stageTarget.className = this.stageClass
    this.closeButtonTarget.hidden = true
    this.expandButtonTarget.hidden = false
    this.stageTarget.removeAttribute("role")
    this.stageTarget.removeAttribute("aria-modal")
    document.body.classList.remove("overflow-hidden")
    this.opener?.focus()
  }
}
