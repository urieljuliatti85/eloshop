import { Controller } from "@hotwired/stimulus"

// Instagram não tem web intent (nenhuma URL do Instagram aceita link/texto
// por parâmetro), então o botão só copia o link do produto para a área de
// transferência — sem abrir folha de compartilhamento, aba ou popup.
export default class extends Controller {
  static targets = ["instagramButton"]
  static values = { url: String }

  async shareOnInstagram(event) {
    event.preventDefault()

    try {
      await navigator.clipboard.writeText(this.urlValue)
      this.flashCopied()
    } catch {
      window.prompt("Copie o link:", this.urlValue)
    }
  }

  flashCopied() {
    const button = this.instagramButtonTarget
    const original = button.innerHTML
    button.textContent = "Link copiado!"
    setTimeout(() => { button.innerHTML = original }, 2000)
  }
}
