import { Controller } from "@hotwired/stimulus"

// Destaca campos obrigatórios vazios (borda vermelha via aria-invalid +
// mensagem) e, ao enviar, leva a tela até o primeiro deles — no celular o
// teclado e a rolagem escondem o campo, e o erro do navegador (balão) some
// sem o usuário perceber o que faltou.
//
// Campos com `data-publish-required` são obrigatórios só para publicar:
// recebem o destaque, mas nunca impedem o envio (o produto pode ser salvo
// como rascunho sem eles).
//
// Campos com `data-required-when="<valor>"` só são obrigatórios enquanto o
// elemento `trigger` (um <select>) tiver esse valor; o asterisco do label
// acompanha. O servidor continua sendo a fonte da verdade das regras.
export default class extends Controller {
  static targets = ["field", "trigger", "marker"]

  connect() {
    this.refresh()
  }

  // Valida só quando o usuário sai do campo (não ao abrir o formulário
  // inteiro vermelho) e limpa o erro assim que ele passa a ser preenchido.
  touch(event) {
    const field = event.target
    if (!this.fieldTargets.includes(field)) return

    if (event.type === "focusout") {
      this.check(field)
    } else if (field.getAttribute("aria-invalid") === "true") {
      this.check(field)
    }
  }

  validate(event) {
    const missing = this.fieldTargets.filter((field) => !this.check(field))
    const blocking = missing.filter((field) => !this.publishOnly(field))

    if (blocking.length > 0) {
      event.preventDefault()
      this.reveal(blocking[0])
    } else if (!this.element.checkValidity()) {
      // Outras regras nativas (min, tipo): o balão do navegador basta.
      event.preventDefault()
      this.element.reportValidity()
    }
  }

  // Liga/desliga a obrigatoriedade dos campos condicionais.
  refresh() {
    const current = this.hasTriggerTarget ? this.triggerTarget.value : null

    this.fieldTargets.forEach((field) => {
      const when = field.dataset.requiredWhen
      if (!when) return

      const required = current === when
      field.required = required
      this.markerFor(field)?.toggleAttribute("hidden", !required)
      if (!required) this.clear(field)
    })
  }

  // true quando o campo está ok (ou não é obrigatório).
  check(field) {
    if (field.required && field.validity.valueMissing) {
      this.flag(field)
      return false
    }

    if (this.publishOnly(field) && field.value.trim() === "") {
      this.flag(field)
      return false
    }

    this.clear(field)
    return true
  }

  flag(field) {
    field.setAttribute("aria-invalid", "true")

    let message = this.messageFor(field)
    if (!message) {
      message = document.createElement("p")
      message.className = "field-error"
      message.id = `${field.id}_error`
      field.insertAdjacentElement("afterend", message)
      field.setAttribute("aria-describedby", message.id)
    }
    message.textContent = this.publishOnly(field) ? "Obrigatório para publicar."
      : field.tagName === "SELECT" ? "Selecione uma opção." : "Preencha este campo."
  }

  clear(field) {
    field.removeAttribute("aria-invalid")
    this.messageFor(field)?.remove()
  }

  reveal(field) {
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    field.focus({ preventScroll: true })
    field.scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth", block: "center" })
  }

  publishOnly(field) {
    return field.dataset.publishRequired !== undefined && !field.required
  }

  messageFor(field) {
    return document.getElementById(`${field.id}_error`)
  }

  markerFor(field) {
    return this.markerTargets.find((marker) => marker.closest("label")?.htmlFor === field.id)
  }
}
