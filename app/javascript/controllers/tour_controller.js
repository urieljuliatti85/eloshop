import { Controller } from "@hotwired/stimulus"

// Tour guiado do painel do vendedor: escurece a tela, destaca um link da
// navegação por vez e explica para que ele serve.
//
// Cada passo aponta para um link que existe em toda página do painel (pelo
// `href`), então o tour nunca navega. Na navegação há duas cópias do link —
// a barra horizontal (lg+) e o painel do hambúrguer (celular) —; vale a
// visível, e no celular o painel é aberto durante o tour e fechado depois.
//
// Abre sozinho enquanto o servidor não registrou a conclusão (`auto`) e
// também por `tour#start`. Concluir ou pular avisa o servidor, que grava o
// marco no vendedor: o tour não reaparece em outro aparelho.
export default class extends Controller {
  static values = { steps: Array, completeUrl: String, auto: Boolean }

  connect() {
    if (this.autoValue) this.start()
  }

  disconnect() {
    this.teardown()
  }

  start() {
    if (this.active || this.stepsValue.length === 0) return

    this.active = true
    this.index = 0
    this.previousFocus = document.activeElement
    this.build()
    this.show()
    this.onKey = (event) => this.handleKey(event)
    this.onResize = () => this.position()
    // O menu do celular fecha em todo `turbo:load` (mobile-menu); como o tour
    // pode abrir durante o carregamento, refaz o passo para reabri-lo.
    // Adiado para depois do fechamento, que roda no mesmo evento.
    this.onLoad = () => setTimeout(() => this.active && this.show(), 0)
    document.addEventListener("turbo:load", this.onLoad)
    document.addEventListener("keydown", this.onKey)
    window.addEventListener("resize", this.onResize)
  }

  next() {
    if (this.index >= this.stepsValue.length - 1) return this.finish()

    this.index += 1
    this.show()
  }

  previous() {
    if (this.index === 0) return

    this.index -= 1
    this.show()
  }

  // Concluir e pular valem igual: senão o tour voltaria a cada acesso.
  finish() {
    this.markCompleted()
    this.teardown()
  }

  build() {
    this.backdrop = document.createElement("div")
    this.backdrop.style.cssText = "position:fixed;inset:0;z-index:2147483000;"

    this.spotlight = document.createElement("div")
    this.spotlight.style.cssText = "position:fixed;z-index:2147483001;border-radius:9999px;pointer-events:none;" +
      "box-shadow:0 0 0 9999px rgba(28,25,23,0.65);transition:all 0.25s ease;"
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) this.spotlight.style.transition = "none"

    this.dialog = document.createElement("div")
    this.dialog.setAttribute("role", "dialog")
    this.dialog.setAttribute("aria-modal", "true")
    this.dialog.setAttribute("aria-live", "polite")
    this.dialog.setAttribute("aria-labelledby", "tour-title")
    this.dialog.tabIndex = -1
    this.dialog.style.cssText = "position:fixed;z-index:2147483002;width:min(20rem,calc(100vw - 2rem));" +
      "background:#fff;border-radius:1rem;padding:1.25rem;box-shadow:0 20px 50px rgba(0,0,0,0.3);"

    document.body.append(this.backdrop, this.spotlight, this.dialog)
  }

  show() {
    const step = this.stepsValue[this.index]
    const last = this.index === this.stepsValue.length - 1
    this.target = this.findTarget(step.path)

    this.dialog.replaceChildren(
      this.element_("p", { text: `Passo ${this.index + 1} de ${this.stepsValue.length}`, style: "font-size:0.7rem;font-weight:700;letter-spacing:0.12em;text-transform:uppercase;color:#a8a29e;" }),
      this.element_("h2", { id: "tour-title", text: step.title, style: "margin-top:0.25rem;font-size:1.125rem;font-weight:800;color:#1c1917;" }),
      this.element_("p", { text: step.body, style: "margin-top:0.5rem;font-size:0.875rem;line-height:1.5;color:#57534e;" }),
      this.actions(last)
    )

    this.position()
    this.dialog.focus({ preventScroll: true })
  }

  actions(last) {
    const row = this.element_("div", { style: "margin-top:1rem;display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:0.5rem;" })
    const skip = this.button(last ? "Fechar" : "Pular tour", () => this.finish(), "background:none;color:#78716c;padding:0.5rem 0.25rem;")
    const group = this.element_("div", { style: "display:flex;gap:0.5rem;" })

    if (this.index > 0) group.append(this.button("Voltar", () => this.previous(), "background:#fff;color:#44403c;border:1px solid #d6d3d1;"))
    group.append(this.button(last ? "Concluir" : "Próximo", () => this.next(), "background:#e8553d;color:#fff;"))
    row.append(last ? group : skip, last ? this.element_("span") : group)
    return row
  }

  button(label, handler, style) {
    const button = this.element_("button", { text: label, style: `min-height:2.75rem;padding:0.5rem 1rem;border-radius:9999px;font-size:0.875rem;font-weight:700;cursor:pointer;${style}` })
    button.type = "button"
    button.addEventListener("click", handler)
    return button
  }

  element_(tag, { text, id, style } = {}) {
    const node = document.createElement(tag)
    if (text) node.textContent = text
    if (id) node.id = id
    if (style) node.style.cssText = style
    return node
  }

  // O link visível entre as cópias da navegação. Sem nenhum visível (celular
  // com o painel fechado), abre o hambúrguer e procura de novo.
  findTarget(path) {
    let target = this.visibleLink(path)
    if (!target) {
      this.openMobileMenu()
      target = this.visibleLink(path)
    }
    return target
  }

  visibleLink(path) {
    return [...document.querySelectorAll(`header a[href="${path}"]`)].find((link) => link.offsetParent !== null)
  }

  // Abre/fecha o painel do hambúrguer direto no DOM, como o `mobile-menu`
  // faz: o tour pode começar antes de esse controller conectar, e um `click`
  // no botão seria perdido.
  openMobileMenu() {
    const { button, panel } = this.mobileMenu()
    if (!button || !panel || !panel.hidden) return

    panel.hidden = false
    button.setAttribute("aria-expanded", "true")
    this.openedMobileMenu = true
  }

  closeMobileMenu() {
    if (!this.openedMobileMenu) return

    const { button, panel } = this.mobileMenu()
    if (panel) panel.hidden = true
    button?.setAttribute("aria-expanded", "false")
    this.openedMobileMenu = false
  }

  mobileMenu() {
    return {
      button: document.querySelector("[data-mobile-menu-target='button']"),
      panel: document.querySelector("[data-mobile-menu-target='panel']")
    }
  }

  position() {
    if (!this.active) return

    if (!this.target) {
      // Sem alvo visível o passo ainda é lido, só não há o que destacar.
      this.spotlight.style.cssText += "left:50%;top:50%;width:0;height:0;"
      this.dialog.style.left = "50%"
      this.dialog.style.top = "50%"
      this.dialog.style.transform = "translate(-50%, -50%)"
      return
    }

    this.target.scrollIntoView({ block: "nearest", inline: "nearest" })
    const rect = this.target.getBoundingClientRect()
    const pad = 6
    Object.assign(this.spotlight.style, {
      left: `${rect.left - pad}px`, top: `${rect.top - pad}px`,
      width: `${rect.width + pad * 2}px`, height: `${rect.height + pad * 2}px`
    })

    const dialogWidth = Math.min(320, window.innerWidth - 32)
    const left = Math.max(16, Math.min(rect.left, window.innerWidth - dialogWidth - 16))
    const below = rect.bottom + 16
    const fitsBelow = below + this.dialog.offsetHeight <= window.innerHeight - 16
    this.dialog.style.transform = "none"
    this.dialog.style.left = `${left}px`
    this.dialog.style.top = `${fitsBelow ? below : Math.max(16, rect.top - this.dialog.offsetHeight - 16)}px`
  }

  handleKey(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.finish()
    } else if (event.key === "ArrowRight") {
      this.next()
    } else if (event.key === "ArrowLeft") {
      this.previous()
    } else if (event.key === "Tab") {
      this.trapFocus(event)
    }
  }

  // O foco fica preso nos botões do balão enquanto o tour está aberto.
  trapFocus(event) {
    const focusable = [...this.dialog.querySelectorAll("button")]
    if (focusable.length === 0) return

    const first = focusable[0]
    const last = focusable[focusable.length - 1]
    if (event.shiftKey && (document.activeElement === first || document.activeElement === this.dialog)) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  teardown() {
    if (!this.active) return

    this.active = false
    document.removeEventListener("turbo:load", this.onLoad)
    document.removeEventListener("keydown", this.onKey)
    window.removeEventListener("resize", this.onResize)
    this.backdrop?.remove()
    this.spotlight?.remove()
    this.dialog?.remove()
    this.closeMobileMenu()
    this.previousFocus?.focus?.({ preventScroll: true })
  }

  markCompleted() {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    fetch(this.completeUrlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": token || "", "Accept": "application/json" },
      credentials: "same-origin"
    }).catch(() => {})
  }
}
