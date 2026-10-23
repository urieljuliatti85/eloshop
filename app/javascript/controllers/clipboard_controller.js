import { Controller } from "@hotwired/stimulus"

// Copia o código PIX copia-e-cola. No celular, quem paga não consegue
// escanear o QR code da própria tela: copiar o código é o caminho principal,
// e selecionar à mão uma linha de 150 caracteres falhava com facilidade.
export default class extends Controller {
  static targets = ["source", "status"]

  async copy() {
    const text = this.sourceTarget.textContent.trim()

    try {
      await navigator.clipboard.writeText(text)
      this.statusTarget.textContent = "Código copiado. Cole no app do seu banco, na área PIX."
    } catch {
      this.selectSource()
      this.statusTarget.textContent = "Não foi possível copiar sozinho. O código está selecionado: copie pelo menu do seu aparelho."
    }
  }

  selectSource() {
    const range = document.createRange()
    range.selectNodeContents(this.sourceTarget)
    const selection = window.getSelection()
    selection.removeAllRanges()
    selection.addRange(range)
  }
}
