import { Controller } from "@hotwired/stimulus"

// Carrossel com scroll-snap: o banner da home e as etapas de "Como funciona"
// no celular. A faixa é uma lista com scroll-snap, então a navegação é feita
// rolando o container — sem transform, sem clonar slides.
// Sem JavaScript os banners continuam alcançáveis pela rolagem horizontal; é
// por isso que os controles nascem `hidden` e só aparecem aqui.
//
// O avanço automático para no hover, no foco do teclado e quando a aba sai de
// vista — e nem começa para quem pediu menos animação no sistema.
//
// Os pontos usam as classes `dot-active`/`dot-inactive` quando a página as
// passa (fundo claro); sem elas, as do banner da home (fundo escuro).
export default class extends Controller {
  static targets = ["track", "slide", "dot", "controls"]
  static values = { interval: { type: Number, default: 7000 } }
  static classes = ["dotActive", "dotInactive"]

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
    const left = this.slideTargets[index].offsetLeft - this.slideTargets[0].offsetLeft
    this.trackTarget.scrollTo({ left, behavior: "smooth" })
    this.syncDots()
    // Uma interação manual reinicia a contagem: avançar sozinho logo depois
    // de alguém clicar rouba o banner que a pessoa acabou de escolher.
    this.restart()
  }

  // A rolagem manual (arrastar no celular) também move o índice, senão os
  // pontos passam a apontar para o slide errado. O passo é a distância entre
  // dois slides (que podem ocupar menos que a largura toda); no fim da
  // rolagem, o último slide é o atual mesmo sem chegar ao início dele.
  onScroll = () => {
    const track = this.trackTarget
    const slides = this.slideTargets
    const step = slides.length > 1 ? slides[1].offsetLeft - slides[0].offsetLeft : track.clientWidth
    const atEnd = track.scrollLeft >= track.scrollWidth - track.clientWidth - 2
    const index = atEnd ? slides.length - 1 : Math.round(track.scrollLeft / step)
    if (index === this.index) return

    this.index = index
    this.syncDots()
  }

  syncDots() {
    const active = this.hasDotActiveClass ? this.dotActiveClasses : ["bg-brand-500", "w-6"]
    const inactive = this.hasDotInactiveClass ? this.dotInactiveClasses : ["bg-white/70"]

    this.dotTargets.forEach((dot, index) => {
      const current = index === this.index
      active.forEach((name) => dot.classList.toggle(name, current))
      inactive.forEach((name) => dot.classList.toggle(name, !current))
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
