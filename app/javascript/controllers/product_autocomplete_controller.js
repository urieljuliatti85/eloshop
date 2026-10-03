import { Controller } from "@hotwired/stimulus"

// Autocomplete da busca da vitrine: enquanto o cliente digita, sugere produtos
// da categoria escolhida no dropdown ao lado (e das filhas dela). Escolher uma
// sugestão abre o produto; Enter sem escolher envia a busca normal.
//
// Sem JavaScript nada se perde: o formulário é um GET comum (categoria + texto)
// que a ProductsController#index já trata. O servidor devolve JSON e o texto
// entra no DOM por textContent — nunca como HTML.
export default class extends Controller {
  static targets = ["input", "list", "category", "option", "status"]
  static values = { url: String, minLength: { type: Number, default: 2 }, delay: { type: Number, default: 200 } }

  connect() {
    this.activeIndex = -1
    this.timer = null
    this.request = null
  }

  disconnect() {
    clearTimeout(this.timer)
    this.request?.abort()
  }

  // Espera uma pausa na digitação antes de ir ao servidor.
  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.fetchSuggestions(), this.delayValue)
  }

  // Trocar a categoria refaz a busca na hora, sem esperar nova digitação.
  refresh() {
    clearTimeout(this.timer)
    if (this.query().length >= this.minLengthValue) this.fetchSuggestions()
    else this.close()
  }

  query() {
    return this.inputTarget.value.trim()
  }

  async fetchSuggestions() {
    const query = this.query()
    if (query.length < this.minLengthValue) return this.close()

    // Resposta antiga não pode sobrescrever a de uma digitação mais nova.
    this.request?.abort()
    this.request = new AbortController()

    const params = new URLSearchParams({ q: query })
    if (this.categoryTarget.value) params.set("category", this.categoryTarget.value)

    try {
      const response = await fetch(`${this.urlValue}?${params}`, {
        headers: { Accept: "application/json" },
        signal: this.request.signal
      })
      if (!response.ok) return this.close()

      const { suggestions } = await response.json()
      this.render(suggestions)
    } catch (error) {
      if (error.name !== "AbortError") this.close()
    }
  }

  render(suggestions) {
    this.listTarget.replaceChildren()
    this.activeIndex = -1

    if (suggestions.length === 0) {
      const empty = document.createElement("li")
      empty.setAttribute("role", "presentation")
      empty.className = "px-3 py-3 text-sm text-ink-muted"
      empty.textContent = "Nenhum produto encontrado."
      this.listTarget.append(empty)
      this.statusTarget.textContent = "Nenhum produto encontrado."
    } else {
      suggestions.forEach((suggestion, index) => this.listTarget.append(this.buildOption(suggestion, index)))
      this.statusTarget.textContent = `${suggestions.length} ${suggestions.length === 1 ? "sugestão" : "sugestões"}. Use as setas para navegar.`
    }

    this.open()
  }

  buildOption(suggestion, index) {
    const item = this.optionTarget.content.firstElementChild.cloneNode(true)
    item.id = `search-suggestion-${index}`
    const link = item.querySelector("a")
    link.href = suggestion.url
    item.querySelector("[data-name]").textContent = suggestion.name
    const category = item.querySelector("[data-category]")
    if (suggestion.category) category.textContent = suggestion.category
    else category.remove()
    return item
  }

  keydown(event) {
    const options = this.options()

    switch (event.key) {
      case "ArrowDown":
        if (this.listTarget.hidden || options.length === 0) return
        event.preventDefault()
        this.activate((this.activeIndex + 1) % options.length)
        break
      case "ArrowUp":
        if (this.listTarget.hidden || options.length === 0) return
        event.preventDefault()
        this.activate((this.activeIndex - 1 + options.length) % options.length)
        break
      case "Enter":
        // Com uma sugestão ativa, abre o produto; sem ela, deixa o formulário
        // enviar a busca normal.
        if (this.activeIndex >= 0 && !this.listTarget.hidden) {
          event.preventDefault()
          options[this.activeIndex].querySelector("a").click()
        }
        break
    }
  }

  options() {
    return Array.from(this.listTarget.querySelectorAll("[role='option']"))
  }

  activate(index) {
    const options = this.options()
    options.forEach((option) => {
      option.setAttribute("aria-selected", "false")
      option.querySelector("a").removeAttribute("aria-selected")
    })

    this.activeIndex = index
    const active = options[index]
    active.setAttribute("aria-selected", "true")
    active.querySelector("a").setAttribute("aria-selected", "true")
    this.inputTarget.setAttribute("aria-activedescendant", active.id)
    active.scrollIntoView({ block: "nearest" })
  }

  open() {
    this.listTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.listTarget.hidden = true
    this.activeIndex = -1
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape() {
    if (this.listTarget.hidden) return

    this.close()
    this.inputTarget.focus()
  }
}
