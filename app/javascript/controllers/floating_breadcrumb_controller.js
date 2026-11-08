import { Controller } from "@hotwired/stimulus"

// Pílula de caminho no celular: fica escondida enquanto o breadcrumb original
// está na tela e aparece quando ele sai pelo topo. O rootMargin de -80px
// considera o cabeçalho fixo, que cobre essa faixa.
export default class extends Controller {
  static targets = ["anchor", "pill"]

  connect() {
    this.observer = new IntersectionObserver(([entry]) => {
      this.pillTarget.hidden = entry.isIntersecting
    }, { rootMargin: "-80px 0px 0px 0px" })
    this.observer.observe(this.anchorTarget)
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
