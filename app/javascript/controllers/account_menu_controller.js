import { Controller } from "@hotwired/stimulus"

// Menu de conta do cabeçalho: o nome de quem está logado abre um painel com
// os dados e os destinos da conta.
//
// Sem JavaScript o painel não abre, mas nada se perde — Pedidos, Favoritos e
// Sair continuam no painel do hambúrguer, e o nome permanece visível no topo.
// Mesmo princípio do menu de busca ao lado.
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
    this.panelTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  // Esc fecha e devolve o foco ao botão, senão o teclado fica órfão no meio
  // do cabeçalho.
  closeOnEscape() {
    if (this.panelTarget.hidden) return

    this.close()
    this.buttonTarget.focus()
  }

  // Turbo mantém o DOM entre navegações: sem isto o painel seguiria aberto na
  // próxima página.
  closeOnNavigation() {
    this.close()
  }
}
