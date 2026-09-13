import { Controller } from "@hotwired/stimulus"

// X e Facebook usam link nativo (href + target="_blank"), sem JS. Instagram
// não tem web intent (só aceita compartilhamento via app nativo), então usamos
// a Web Share API do navegador: no mobile ela abre a folha de compartilhamento
// do sistema, de onde o cliente escolhe Instagram Stories/DM já com a imagem
// e o link do produto. Sem suporte (a maioria dos desktops), caímos para
// copiar o link em uma nova aba.
export default class extends Controller {
  static values = { url: String, title: String, imageUrl: String }

  async shareOnInstagram(event) {
    event.preventDefault()

    if (navigator.share && navigator.canShare) {
      const shared = await this.shareViaSystemSheet()
      if (shared) return
    }

    const tab = window.open("about:blank", "_blank", "noopener,noreferrer")
    if (tab) this.renderFallbackTab(tab)
  }

  async shareViaSystemSheet() {
    try {
      const files = await this.buildImageFile()
      const data = { title: this.titleValue, text: this.titleValue, url: this.urlValue }
      if (files) data.files = files

      if (data.files && !navigator.canShare({ files: data.files })) delete data.files

      await navigator.share(data)
      return true
    } catch (error) {
      // AbortError: o cliente cancelou a folha de compartilhamento — não é falha.
      return error?.name === "AbortError"
    }
  }

  async buildImageFile() {
    if (!this.imageUrlValue) return null

    try {
      const response = await fetch(this.imageUrlValue)
      const blob = await response.blob()
      const extension = blob.type.split("/")[1] || "jpg"
      return [new File([blob], `produto.${extension}`, { type: blob.type })]
    } catch {
      return null
    }
  }

  renderFallbackTab(tab) {
    const url = this.urlValue
    tab.document.title = "Compartilhar no Instagram"
    tab.document.body.style.cssText = "font-family: sans-serif; padding: 24px; color: #1a1a1a; max-width: 480px; margin: 0 auto;"
    tab.document.body.innerHTML = `
      <p style="margin: 0 0 12px; font-size: 14px;">Seu navegador não suporta compartilhamento direto. Copie o link abaixo e cole na sua bio ou em um story:</p>
      <input type="text" readonly style="width: 100%; padding: 8px; font-size: 13px; box-sizing: border-box;">
    `
    const input = tab.document.querySelector("input")
    input.value = url
    input.addEventListener("focus", () => input.select())
    input.focus()
  }
}
