import { Controller } from "@hotwired/stimulus"

// "Selecionar todos" nas listagens de produtos do painel do vendedor e do
// admin: um checkbox no cabeçalho marca/desmarca todos os checkboxes de
// linha, sem exigir uma ação separada de servidor.
export default class extends Controller {
  static targets = ["selectAll", "row"]

  toggleAll() {
    this.rowTargets.forEach((checkbox) => {
      checkbox.checked = this.selectAllTarget.checked
    })
  }
}
