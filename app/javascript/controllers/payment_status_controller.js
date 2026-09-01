import { Controller } from "@hotwired/stimulus"

// A confirmação do PIX chega por webhook. Enquanto o pagamento estiver em
// andamento, atualiza somente o bloco de status; este endpoint nunca cria uma
// cobrança nova.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.timer = window.setInterval(() => this.refresh(), 3000)
  }

  disconnect() {
    window.clearInterval(this.timer)
  }

  async refresh() {
    if (this.refreshing) return

    this.refreshing = true

    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "text/html" },
        credentials: "same-origin"
      })

      if (!response.ok) return

      this.element.outerHTML = await response.text()
    } catch {
      // Falha transitória de rede: o próximo intervalo tenta novamente.
    } finally {
      this.refreshing = false
    }
  }
}
