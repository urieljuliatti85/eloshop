import { Controller } from "@hotwired/stimulus"

// Atalho "Voltar ao topo" do painel inicial no celular: só aparece quando o menu
// "Nesta página" saiu da tela, e leva de volta a ele pela âncora.
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.observer = new IntersectionObserver(([entry]) => {
      this.buttonTarget.hidden = entry.isIntersecting
    })
    this.observer.observe(this.menuTarget)
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
