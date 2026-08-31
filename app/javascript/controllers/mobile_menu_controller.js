import { Controller } from "@hotwired/stimulus"

// Menu de navegação em telas estreitas. Os links de topo ficam escondidos a
// partir do breakpoint md; sem este painel não há como chegar à Loja, ao
// Contato ou ao login pelo cabeçalho no celular.
export default class extends Controller {
  static targets = ["panel", "button"]

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    if (this.panelTarget.hidden) return
    this.panelTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  closeOnEscape() {
    if (this.panelTarget.hidden) return
    this.close()
    this.buttonTarget.focus()
  }

  // Turbo troca o corpo da página sem recarregar: sem isto o painel
  // continuaria aberto por cima da página seguinte.
  closeOnNavigation() {
    this.close()
  }
}
