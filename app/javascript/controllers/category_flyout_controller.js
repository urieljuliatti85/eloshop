import { Controller } from "@hotwired/stimulus"

// Menu "Ver todos" da vitrine: uma coluna de categorias de topo e, ao lado,
// as filhas da categoria em foco (submenu lateral). A partir de `sm` isso é
// um painel de duas colunas, em que o mouse e as setas trocam a categoria em
// foco; no celular não há largura para uma segunda coluna, então tocar numa
// categoria expande a lista de filhas por baixo dela (abre e fecha).
//
// Abrir/fechar o painel inteiro (clique fora, Esc) é do `account-menu`.
// Sem JavaScript o painel não abre, mas as pílulas da faixa seguem levando a
// todas as categorias.
export default class extends Controller {
  static targets = ["root", "children"]
  static values = { current: String }

  desktop() {
    return window.matchMedia("(min-width: 640px)").matches
  }

  // Ao abrir o painel: no desktop já mostra as filhas (da categoria atual, ou
  // da primeira), para a coluna da direita não nascer vazia. No celular abre
  // tudo recolhido.
  openDefault() {
    if (!this.desktop() || this.rootTargets.length === 0) return

    const root = this.rootTargets.find((candidate) => candidate.dataset.rootId === this.currentValue) || this.rootTargets[0]
    this.show(root)
  }

  // Clique/toque. No desktop sempre abre; no celular alterna.
  select(event) {
    const root = event.currentTarget
    if (!this.desktop() && root.getAttribute("aria-expanded") === "true") return this.hideAll()

    this.show(root)
  }

  // Passar o mouse troca a categoria em foco (só no desktop).
  hover(event) {
    if (this.desktop()) this.show(event.currentTarget)
  }

  show(root) {
    this.hideAll()
    root.setAttribute("aria-expanded", "true")
    root.querySelector("[data-chevron]")?.classList.add("rotate-180")
    this.childrenFor(root).hidden = false
  }

  hideAll() {
    this.rootTargets.forEach((root) => {
      root.setAttribute("aria-expanded", "false")
      root.querySelector("[data-chevron]")?.classList.remove("rotate-180")
    })
    this.childrenTargets.forEach((list) => { list.hidden = true })
  }

  childrenFor(root) {
    return this.childrenTargets.find((list) => list.dataset.rootId === root.dataset.rootId)
  }

  // Teclado na coluna de categorias: ↑ ↓ andam entre elas (e já mostram as
  // filhas no desktop), → entra nas filhas.
  rootKeydown(event) {
    const index = this.rootTargets.indexOf(event.currentTarget)

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      const next = this.rootTargets[(index + step + this.rootTargets.length) % this.rootTargets.length]
      next.focus()
      if (this.desktop()) this.show(next)
    } else if (event.key === "ArrowRight" || (event.key === "Enter" && this.desktop())) {
      event.preventDefault()
      this.show(event.currentTarget)
      this.childrenFor(event.currentTarget).querySelector("a")?.focus()
    }
  }

  // Teclado nas filhas: ↑ ↓ andam entre elas, ← volta para a categoria.
  childKeydown(event) {
    const list = event.currentTarget.closest("ul")
    const links = Array.from(list.querySelectorAll("a"))
    const index = links.indexOf(event.currentTarget)

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      links[(index + step + links.length) % links.length].focus()
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.rootTargets.find((root) => root.dataset.rootId === list.dataset.rootId)?.focus()
    }
  }
}
