import { Controller } from "@hotwired/stimulus"

// Formata e valida o CNPJ enquanto a pessoa digita, no mesmo molde do
// cpf_input_controller: "12345678000195" vira "12.345.678/0001-95".
//
// Desde julho de 2026 a Receita emite CNPJ alfanumérico: as 12 primeiras
// posições aceitam letras maiúsculas e dígitos; os 2 verificadores continuam
// numéricos. Letras digitadas em minúsculas viram maiúsculas, separadores são
// ignorados e o que passar de 14 caracteres é descartado.
//
// A validação é o mesmo módulo 11 do servidor (Cnpj.valid?), com cada
// caractere valendo o código ASCII menos 48 (A = 17). O campo é opcional:
// vazio não é cobrado; com os 14 caracteres, ou ao sair do campo, o erro
// aparece abaixo e o navegador não deixa enviar (setCustomValidity). É
// conveniência: o servidor normaliza e valida de novo.
export default class extends Controller {
  static targets = ["input", "message"]

  static FIRST_WEIGHTS = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
  static SECOND_WEIGHTS = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]

  connect() {
    if (this.inputTarget.value.trim() !== "") {
      this.format()
      this.validate()
    }
  }

  format() {
    const input = this.inputTarget
    const caret = input.selectionStart ?? input.value.length
    const charsBeforeCaret = this.normalize(input.value.slice(0, caret)).length

    const chars = this.normalize(input.value).slice(0, 14)
    input.value = this.mask(chars)

    if (document.activeElement === input) {
      const position = this.positionAfterChars(input.value, charsBeforeCaret)
      input.setSelectionRange(position, position)
    }

    if (chars.length === 14) {
      this.validate()
    } else {
      this.showMessage("")
    }
  }

  validate() {
    this.showMessage(this.problemWith(this.normalize(this.inputTarget.value)))
  }

  normalize(value) {
    return value.toUpperCase().replace(/[^0-9A-Z]/g, "")
  }

  problemWith(chars) {
    if (chars === "") return ""
    if (chars.length < 14) {
      const missing = 14 - chars.length
      return `O CNPJ tem 14 caracteres. ${missing === 1 ? "Falta 1" : `Faltam ${missing}`}.`
    }
    if (!/^[0-9A-Z]{12}\d{2}$/.test(chars)) return "Os 2 últimos caracteres do CNPJ são números."
    if (!this.validChecksum(chars)) return "CNPJ inválido: confira se algum caractere foi digitado errado."
    return ""
  }

  validChecksum(chars) {
    if (/^(.)\1{13}$/.test(chars)) return false

    const first = this.checkDigit(chars.slice(0, 12), this.constructor.FIRST_WEIGHTS)
    const second = this.checkDigit(chars.slice(0, 13), this.constructor.SECOND_WEIGHTS)
    return first === Number(chars[12]) && second === Number(chars[13])
  }

  checkDigit(base, weights) {
    const sum = base.split("").reduce((total, char, index) => total + (char.charCodeAt(0) - 48) * weights[index], 0)
    const remainder = sum % 11
    return remainder < 2 ? 0 : 11 - remainder
  }

  showMessage(message) {
    this.inputTarget.setCustomValidity(message)
    this.inputTarget.setAttribute("aria-invalid", message ? "true" : "false")
    if (!this.hasMessageTarget) return

    this.messageTarget.textContent = message
    this.messageTarget.hidden = message === ""
  }

  // 12.ABC.345/01DE-35
  mask(chars) {
    const parts = [chars.slice(0, 2), chars.slice(2, 5), chars.slice(5, 8)].filter((part) => part !== "")
    let formatted = parts.join(".")
    if (chars.length > 8) formatted += `/${chars.slice(8, 12)}`
    if (chars.length > 12) formatted += `-${chars.slice(12)}`
    return formatted
  }

  positionAfterChars(value, count) {
    if (count === 0) return 0

    let seen = 0
    for (let index = 0; index < value.length; index++) {
      if (/[0-9A-Z]/.test(value[index])) seen++
      if (seen === count) return index + 1
    }
    return value.length
  }
}
