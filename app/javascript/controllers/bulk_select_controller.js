import { Controller } from "@hotwired/stimulus"

// "Selecionar todos" nas listagens de produtos do painel do vendedor e do
// admin: um checkbox no cabeçalho marca/desmarca todos os checkboxes de
// linha, sem exigir uma ação separada de servidor.
//
// Opcionais: `action` (botões em massa, desabilitados sem seleção) e `count`
// ("N selecionados", anunciado por leitor de tela). Sem JS os botões ficam
// habilitados e o servidor continua sendo quem valida a seleção.
export default class extends Controller {
  static targets = ["selectAll", "row", "action", "count"]

  connect() {
    this.refresh()
  }

  toggleAll() {
    this.rowTargets.forEach((checkbox) => {
      checkbox.checked = this.selectAllTarget.checked
    })
    this.refresh()
  }

  refresh() {
    // Cada produto tem um checkbox no cartão (celular) e outro na tabela
    // (desktop); conta valores distintos para não dobrar o número.
    const selected = new Set(this.rowTargets.filter((checkbox) => checkbox.checked).map((checkbox) => checkbox.value))
    this.actionTargets.forEach((button) => { button.disabled = selected.size === 0 })
    if (this.hasCountTarget) {
      this.countTarget.textContent = selected.size === 0 ? "" : `${selected.size} selecionado${selected.size === 1 ? "" : "s"}`
    }
  }
}
