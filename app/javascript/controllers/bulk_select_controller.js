import { Controller } from "@hotwired/stimulus"

// "Selecionar todos" nas listagens de produtos do painel do vendedor e do
// admin: um checkbox no cabeçalho marca/desmarca todos os checkboxes de
// linha, sem exigir uma ação separada de servidor.
//
// Opcionais: `action` (botões em massa, desabilitados sem seleção), `count`
// ("N selecionados", anunciado por leitor de tela) e `bar` (some sem seleção).
// Sem JS os botões ficam visíveis e habilitados, e o servidor continua sendo
// quem valida a seleção.
export default class extends Controller {
  static targets = ["selectAll", "row", "action", "count", "bar"]

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
    this.barTargets.forEach((bar) => { bar.hidden = selected.size === 0 })
    if (this.hasCountTarget) {
      this.countTarget.textContent = selected.size === 0 ? "" : `${selected.size} selecionado${selected.size === 1 ? "" : "s"}`
    }
  }
}
