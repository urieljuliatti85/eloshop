import { Controller } from "@hotwired/stimulus"

// Faixa de rolagem horizontal (áreas do admin no topo do celular): traz o
// item da página atual (`aria-current="page"`) para o centro, senão uma área
// do fim da lista fica ativa fora da tela. Mexe só no scrollLeft da faixa —
// `scrollIntoView` também rolaria a página na vertical.
export default class extends Controller {
  connect() {
    const current = this.element.querySelector("[aria-current='page']")
    if (!current) return

    this.element.scrollLeft = current.offsetLeft - (this.element.clientWidth - current.offsetWidth) / 2
  }
}
