import { Controller } from "@hotwired/stimulus"

// Tabelas do admin viram lista de cartões abaixo de `lg` (ver
// `.admin-content table` em application.css): o CSS mostra o nome da coluna
// ao lado de cada valor a partir de `data-label`, que este controller copia
// do <thead> — assim nenhuma view repete os rótulos e eles nunca divergem do
// cabeçalho.
//
// - A primeira coluna com nome vira o título do cartão (`data-primary`).
// - Colunas sem nome (ações, checkbox) ficam sem rótulo.
// - Células com colspan (linha de "nenhum registro") ficam sem rótulo.
// - Setas de ordenação (aria-hidden) e textos só para leitor de tela não
//   entram no rótulo.
export default class extends Controller {
  connect() {
    this.element.querySelectorAll("table").forEach((table) => this.label(table))
  }

  label(table) {
    const headers = [...table.querySelectorAll("thead th")].map((th) => this.text(th))
    const primary = headers.findIndex((label) => label !== "")

    table.querySelectorAll("tbody tr").forEach((row) => {
      let column = 0
      for (const cell of row.cells) {
        if (cell.colSpan === 1) {
          const label = headers[column] ?? ""
          if (column === primary) cell.dataset.primary = ""
          else if (label) cell.dataset.label = label
        }
        column += cell.colSpan
      }
    })
  }

  text(th) {
    const copy = th.cloneNode(true)
    copy.querySelectorAll("[aria-hidden='true'], .sr-only").forEach((element) => element.remove())
    return copy.textContent.replace(/\s+/g, " ").trim()
  }
}
