import { Controller } from "@hotwired/stimulus"

// Mensagens de sucesso ficam visíveis até que a pessoa as dispense. Isso
// evita que uma confirmação importante desapareça antes de ser lida.
export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}
