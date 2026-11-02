import { Controller } from "@hotwired/stimulus"

// Botão "Marcar"/"Desmarcar" ao lado de uma caixa de seleção: um alvo de
// toque maior no celular. Só inverte a caixa e avisa quem escuta `change`;
// o texto do botão e o aviso que depende dela seguem o estado por CSS
// (`:has(:checked)`), então não há estado duplicado aqui.
export default class extends Controller {
  static targets = ["checkbox"]

  toggle() {
    this.checkboxTarget.checked = !this.checkboxTarget.checked
    this.checkboxTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
