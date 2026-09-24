import { Controller } from "@hotwired/stimulus"

// Confirma só ao marcar (não ao desmarcar) — usado no checkbox de frete
// grátis do produto, para o vendedor não ativar sem perceber que passa a
// assumir o custo do envio. Reverte o check se ele cancelar.
export default class extends Controller {
  static values = { message: String }

  confirm(event) {
    if (!event.target.checked) return

    if (!window.confirm(this.messageValue)) {
      event.target.checked = false
    }
  }
}
