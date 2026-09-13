import { Controller } from "@hotwired/stimulus"

// Troca de aba sem recarregar a página, refletindo a escolha na URL via
// history.replaceState — assim um link direto com ?aba=vende abre já na
// aba certa, e trocar de aba no clique não perde a posição de rolagem.
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { param: { type: String, default: "aba" } }

  connect() {
    const requested = new URLSearchParams(window.location.search).get(this.paramValue)
    const initial = this.tabTargets.find((tab) => tab.dataset.tabName === requested) || this.tabTargets[0]
    if (initial) this.activate(initial)
  }

  select(event) {
    this.activate(event.currentTarget)
    this.updateUrl(event.currentTarget.dataset.tabName)
  }

  activate(selectedTab) {
    this.tabTargets.forEach((tab) => {
      const active = tab === selectedTab
      tab.setAttribute("aria-selected", active ? "true" : "false")
      tab.classList.toggle("bg-white", active)
      tab.classList.toggle("shadow-sm", active)
      tab.classList.toggle("text-brand-600", active)
      tab.classList.toggle("text-ink-muted", !active)
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.tabName !== selectedTab.dataset.tabName
    })
  }

  updateUrl(tabName) {
    const url = new URL(window.location)
    url.searchParams.set(this.paramValue, tabName)
    window.history.replaceState({}, "", url)
  }
}
