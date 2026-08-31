import { Controller } from "@hotwired/stimulus"

// Abre o campo de busca do cabeçalho a partir do ícone de lupa. O formulário
// aponta para a loja (parâmetro `q`, que o ProductsController já trata), então
// sem JavaScript nada se perde: a busca continua disponível dentro do filtro
// da vitrine.
export default class extends Controller {
  static targets = ["panel", "input"]

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.element.setAttribute("aria-expanded", "true")
    this.inputTarget.focus()
  }

  close() {
    this.panelTarget.hidden = true
    this.element.setAttribute("aria-expanded", "false")
  }

  // Fecha ao clicar fora ou ao pressionar Esc — ambos ligados no window pelo
  // data-action, porque o painel cobre a largura toda do cabeçalho.
  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape() {
    if (this.panelTarget.hidden) return
    this.close()
    this.element.querySelector("button").focus()
  }
}
