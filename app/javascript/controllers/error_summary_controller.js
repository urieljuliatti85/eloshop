import { Controller } from "@hotwired/stimulus"

// Leva a pessoa até a lista de erros quando um formulário volta inválido.
// Quem clicou em enviar está no fim da página, e a lista fica no topo: sem
// isto, o formulário reaparecia sem nenhum aviso à vista. O foco também faz
// o leitor de tela ler a lista.
export default class extends Controller {
  connect() {
    this.element.scrollIntoView({ block: "start" })
    this.element.focus({ preventScroll: true })
  }
}
