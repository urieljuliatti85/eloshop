import { Controller } from "@hotwired/stimulus"

// Carrossel do banner da home. A faixa é uma lista com scroll-snap, então a
// navegação é feita rolando o container — sem transform, sem clonar slides.
// Sem JavaScript os banners continuam alcançáveis pela rolagem horizontal; é
// por isso que os controles nascem `hidden` e só aparecem aqui.
//
// O avanço automático para no hover, no foco do teclado e quando a aba sai de
// vista — e nem começa para quem pediu menos animação no sistema.
export default class extends Controller {
  static targets = ["track", "slide", "dot", "controls"]
  static values = { interval: { type: Number, default: 7000 } }

  connect() {
    this.controlsTarget.hidden = false
    this.element.tabIndex = 0
    this.index = 0
    this.syncDots()

    this.trackTarget.addEventListener("scroll", this.onScroll)
    this.start()
  }

  disconnect() {
    this.stop()
    this.trackTarget.removeEventListener("scroll", this.onScroll)
  }

  next() {
    this.scrollTo((this.index + 1) % this.slideTargets.length)
  }

  previous() {
    this.scrollTo((this.index - 1 + this.slideTargets.length) % this.slideTargets.length)
  }

  goTo(event) {
    this.scrollTo(Number(event.currentTarget.dataset.index))
  }

  scrollTo(index) {
    this.index = index
    this.trackTarget.scrollTo({ left: this.slideTargets[index].offsetLeft, behavior: "smooth" })
    this.syncDots()
    // Uma interação manual reinicia a contagem: avançar sozinho logo depois
    // de alguém clicar rouba o banner que a pessoa acabou de escolher.
    this.restart()
  }

  // A rolagem manual (arrastar no celular) também move o índice, senão os
  // pontos passam a apontar para o slide errado.
  onScroll = () => {
    const index = Math.round(this.trackTarget.scrollLeft / this.trackTarget.clientWidth)
    if (index === this.index) return

    this.index = index
    this.syncDots()
  }

  syncDots() {
    this.dotTargets.forEach((dot, index) => {
      const current = index === this.index
      dot.classList.toggle("bg-brand-500", current)
      dot.classList.toggle("w-6", current)
      dot.classList.toggle("bg-gray-300", !current)
      dot.setAttribute("aria-selected", current)
    })
  }

  start() {
    // interval 0 desliga o avanço — é como os testes de sistema evitam que o
    // banner se mova sozinho no meio de um clique.
    if (this.intervalValue <= 0) return
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.timer = setInterval(() => {
      if (document.hidden) return
      this.next()
    }, this.intervalValue)
  }

  stop() {
    clearInterval(this.timer)
  }

  restart() {
    this.stop()
    this.start()
  }
}
