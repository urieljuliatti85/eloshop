import { Controller } from "@hotwired/stimulus"

// Galeria da PDP: a miniatura troca a foto principal (só no cliente, sem
// round-trip) e a foto principal abre ampliada num <dialog> nativo.
//
// A ampliação mostra a foto que está à vista: `show` guarda a URL e o texto
// alternativo da miniatura escolhida, e `open` os copia para o dialog. A URL
// é a da rota do Active Storage (`url_for(variant)`), que não expira — a URL
// direta do serviço expira em minutos.
export default class extends Controller {
  static targets = ["main", "dialog", "zoom"]

  show(event) {
    this.mainTarget.src = event.params.src
    if (event.params.alt) this.mainTarget.alt = event.params.alt
  }

  open(event) {
    if (!this.hasDialogTarget || this.dialogTarget.open) return

    this.opener = event.currentTarget
    this.zoomTarget.src = this.mainTarget.currentSrc || this.mainTarget.src
    this.zoomTarget.alt = this.mainTarget.alt
    // O fundo não rola atrás da foto (no iOS, rolava a página por baixo).
    document.documentElement.classList.add("overflow-hidden")
    this.dialogTarget.showModal()
  }

  close() {
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
  }

  // Clique no fundo escuro (fora da foto e do botão) fecha.
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget || event.target === this.dialogTarget.firstElementChild) this.close()
  }

  // Disparado por qualquer fechamento: botão, Esc, fundo ou Turbo.
  closed() {
    document.documentElement.classList.remove("overflow-hidden")
    this.opener?.focus({ preventScroll: true })
    this.opener = null
  }

  disconnect() {
    this.close()
    document.documentElement.classList.remove("overflow-hidden")
  }
}
