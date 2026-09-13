import { Controller } from "@hotwired/stimulus"

// X e Facebook usam link nativo (href + target="_blank"), sem JS. Instagram
// não tem endpoint web de compartilhamento (só o app aceita share direto),
// então abrimos uma nova aba mostrando o link do produto para o cliente copiar.
export default class extends Controller {
  static values = { url: String }

  shareOnInstagram(event) {
    event.preventDefault()
    const tab = window.open("about:blank", "_blank", "noopener,noreferrer")
    if (tab) this.renderInstagramTab(tab)
  }

  renderInstagramTab(tab) {
    const url = this.urlValue
    tab.document.title = "Compartilhar no Instagram"
    tab.document.body.style.cssText = "font-family: sans-serif; padding: 24px; color: #1a1a1a; max-width: 480px; margin: 0 auto;"
    tab.document.body.innerHTML = `
      <p style="margin: 0 0 12px; font-size: 14px;">O Instagram não permite compartilhar um link diretamente. Copie o link abaixo e cole na sua bio ou em um story:</p>
      <input type="text" readonly style="width: 100%; padding: 8px; font-size: 13px; box-sizing: border-box;">
    `
    const input = tab.document.querySelector("input")
    input.value = url
    input.addEventListener("focus", () => input.select())
    input.focus()
  }
}
