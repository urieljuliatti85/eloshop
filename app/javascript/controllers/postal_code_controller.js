import { Controller } from "@hotwired/stimulus"

// Preenche o endereço por CEP e sugere logradouros por UF/cidade/rua. Consulta
// o próprio backend, nunca a API de CEP direto do navegador — a CSP restringe
// connect_src a :self.
export default class extends Controller {
  static targets = ["zipCode", "street", "neighborhood", "city", "state", "suggestions", "status"]
  static values = { url: String, searchUrl: String }

  connect() {
    this.searchTimeout = null
    this.lookupRequest = null
    this.searchRequest = null
  }

  disconnect() {
    clearTimeout(this.searchTimeout)
    this.lookupRequest?.abort()
    this.searchRequest?.abort()
  }

  lookup() {
    const digits = this.zipCodeTarget.value.replace(/\D/g, "")
    if (digits.length !== 8) return

    this.lookupRequest?.abort()
    this.lookupRequest = new AbortController()
    this.setStatus("Buscando CEP…")

    fetch(this.urlValue.replace("00000000", digits), {
      headers: { Accept: "application/json" },
      signal: this.lookupRequest.signal
    })
      .then((response) => (response.ok ? response.json() : null))
      .then((address) => {
        if (!address) {
          this.setStatus("CEP não encontrado. Você pode preencher o endereço manualmente.")
          return
        }

        this.applyAddress(address, false)
        this.clearSuggestions()
        this.setStatus("Endereço preenchido pelo CEP.")
      })
      .catch((error) => {
        if (error.name !== "AbortError") this.setStatus("Não foi possível consultar o CEP. Preencha manualmente.")
      })
  }

  search() {
    if (!this.hasSearchUrlValue) return

    clearTimeout(this.searchTimeout)
    const state = this.stateTarget.value.trim().toUpperCase()
    const city = this.cityTarget.value.trim()
    const street = this.streetTarget.value.trim()

    if (state.length !== 2 || city.length < 3 || street.length < 3) {
      this.clearSuggestions()
      this.setStatus("")
      return
    }

    this.searchTimeout = setTimeout(() => this.fetchSuggestions({ state, city, street }), 350)
  }

  fetchSuggestions({ state, city, street }) {
    this.searchRequest?.abort()
    this.searchRequest = new AbortController()
    const url = new URL(this.searchUrlValue, window.location.origin)
    url.search = new URLSearchParams({ state, city, street }).toString()
    this.setStatus("Buscando ruas…")

    fetch(url, {
      headers: { Accept: "application/json" },
      signal: this.searchRequest.signal
    })
      .then((response) => (response.ok ? response.json() : []))
      .then((suggestions) => this.renderSuggestions(suggestions))
      .catch((error) => {
        if (error.name !== "AbortError") {
          this.clearSuggestions()
          this.setStatus("Não foi possível buscar a rua. Continue preenchendo manualmente.")
        }
      })
  }

  renderSuggestions(suggestions) {
    this.clearSuggestions()

    if (suggestions.length === 0) {
      this.setStatus("Nenhuma rua encontrada. Continue preenchendo manualmente.")
      return
    }

    suggestions.forEach((address) => {
      const button = document.createElement("button")
      button.type = "button"
      button.role = "option"
      button.className = "block w-full border-b border-gray-100 px-3 py-3 text-left text-sm text-ink last:border-0 hover:bg-brand-50 focus:bg-brand-50 focus:outline-none"
      button.textContent = [
        address.street,
        address.neighborhood,
        `${address.city}/${address.state}`,
        `CEP ${address.zip_code}`
      ].filter(Boolean).join(" · ")
      button.addEventListener("click", () => {
        this.applyAddress(address, true)
        this.clearSuggestions()
        this.setStatus("Endereço selecionado.")
      })
      this.suggestionsTarget.appendChild(button)
    })

    this.suggestionsTarget.hidden = false
    this.setStatus(`${suggestions.length} ${suggestions.length === 1 ? "endereço encontrado" : "endereços encontrados"}.`)
  }

  applyAddress(address, includeZipCode) {
    if (includeZipCode) this.zipCodeTarget.value = address.zip_code
    this.streetTarget.value = address.street
    this.neighborhoodTarget.value = address.neighborhood
    this.cityTarget.value = address.city
    this.stateTarget.value = address.state
  }

  clearSuggestions() {
    if (!this.hasSuggestionsTarget) return

    this.suggestionsTarget.replaceChildren()
    this.suggestionsTarget.hidden = true
  }

  setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
