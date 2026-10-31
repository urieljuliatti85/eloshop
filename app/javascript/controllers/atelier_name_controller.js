import { Controller } from "@hotwired/stimulus"

// Confere, enquanto o artesão digita, se já existe um ateliê com o mesmo nome
// (ou que gere o mesmo slug). Se existir, bloqueia o envio e oferece um nome
// livre. O backend continua sendo quem garante a unicidade.
export default class extends Controller {
  static targets = ["input", "status"]
  static values = { url: String }

  connect() {
    this.timeout = null
    this.request = null
  }

  disconnect() {
    clearTimeout(this.timeout)
    this.request?.abort()
  }

  check() {
    clearTimeout(this.timeout)
    this.request?.abort()
    this.inputTarget.setCustomValidity("")

    const name = this.inputTarget.value.trim()
    if (name.length < 2) {
      this.setStatus("")
      return
    }

    this.timeout = setTimeout(() => this.fetchAvailability(name), 350)
  }

  fetchAvailability(name) {
    this.request = new AbortController()
    const url = new URL(this.urlValue, window.location.origin)
    url.search = new URLSearchParams({ name }).toString()

    fetch(url, { headers: { Accept: "application/json" }, signal: this.request.signal })
      .then((response) => (response.ok ? response.json() : null))
      .then((result) => {
        if (result && this.inputTarget.value.trim() === name) this.render(result)
      })
      .catch((error) => {
        if (error.name !== "AbortError") this.setStatus("")
      })
  }

  render(result) {
    if (!result.valid) {
      this.block("Use letras ou números no nome do ateliê.")
    } else if (result.available) {
      this.inputTarget.setCustomValidity("")
      this.setStatus(`Nome disponível. Endereço: /artesaos/${result.slug}`, "text-green-700")
    } else {
      this.block("Já existe um ateliê com esse nome (ou com uma URL igual).", result.suggestion)
    }
  }

  block(message, suggestion) {
    this.inputTarget.setCustomValidity(message)
    this.statusTarget.className = "mt-2 text-sm text-red-700"
    this.statusTarget.textContent = `${message} `

    if (suggestion) {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "font-semibold underline"
      button.textContent = `Usar "${suggestion}"`
      button.addEventListener("click", () => {
        this.inputTarget.value = suggestion
        this.check()
        this.inputTarget.focus()
      })
      this.statusTarget.appendChild(button)
    }
  }

  setStatus(message, color = "text-ink-muted") {
    this.statusTarget.className = `mt-2 text-sm ${color}`
    this.statusTarget.textContent = message
  }
}
