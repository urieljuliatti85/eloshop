import { Controller } from "@hotwired/stimulus"

// Confere, enquanto o comprador digita, se o e-mail serve para o cadastro:
// verde quando está livre, vermelho quando já tem conta ou não é um e-mail.
// Bloqueia o envio nos casos vermelhos; o backend continua sendo quem garante
// a unicidade.
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
    this.paint(null)

    const email = this.inputTarget.value.trim()
    // Sem "@" ainda não há o que conferir; evita uma consulta por tecla.
    if (!email.includes("@")) {
      this.setStatus("")
      return
    }

    this.timeout = setTimeout(() => this.fetchAvailability(email), 400)
  }

  fetchAvailability(email) {
    this.request = new AbortController()
    const url = new URL(this.urlValue, window.location.origin)
    url.search = new URLSearchParams({ email }).toString()

    fetch(url, { headers: { Accept: "application/json" }, signal: this.request.signal })
      .then((response) => (response.ok ? response.json() : null))
      .then((result) => {
        if (result && this.inputTarget.value.trim() === email) this.render(result)
      })
      .catch((error) => {
        if (error.name !== "AbortError") this.setStatus("")
      })
  }

  render(result) {
    if (!result.valid) {
      this.block("Digite um e-mail válido.")
    } else if (result.available) {
      this.setStatus("E-mail disponível para cadastro.", "text-green-700")
      this.paint(true)
    } else {
      this.block("Este e-mail já tem cadastro. Use a aba \"Já sou cliente\" para entrar.")
    }
  }

  block(message) {
    this.inputTarget.setCustomValidity(message)
    this.setStatus(message, "text-red-700")
    this.paint(false)
  }

  // Borda do campo: verde quando livre, vermelha (a de campo obrigatório) nos demais casos.
  paint(available) {
    const input = this.inputTarget
    input.classList.toggle("border-green-600", available === true)
    input.classList.toggle("focus:border-green-700", available === true)
    input.classList.toggle("border-red-400", available !== true)
    input.classList.toggle("focus:border-red-600", available !== true)
  }

  setStatus(message, color = "text-ink-muted") {
    this.statusTarget.className = `mt-2 text-sm ${color}`
    this.statusTarget.textContent = message
  }
}
