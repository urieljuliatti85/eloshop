import { Controller } from "@hotwired/stimulus"

// X e Facebook usam link nativo (href + target="_blank"), sem JS. Instagram
// não tem web intent (nenhuma URL do Instagram aceita link/texto por
// parâmetro), então usamos a Web Share API do navegador: no mobile ela abre
// a folha de compartilhamento nativa do sistema com título, link e a imagem
// do produto, de onde o cliente escolhe Instagram Stories/DM. Sem suporte
// (a maioria dos desktops), copiamos o link para a área de transferência —
// nunca abrimos aba ou popup, para não deixar uma tela em branco.
export default class extends Controller {
  static targets = ["instagramButton"]
  static values = { url: String, title: String, imageUrl: String }

  async shareOnInstagram(event) {
    event.preventDefault()

    if (navigator.share && navigator.canShare) {
      const shared = await this.shareViaSystemSheet()
      if (shared) return
    }

    await this.copyLink()
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

  async copyLink() {
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
