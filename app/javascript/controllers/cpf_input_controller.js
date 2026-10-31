import { Controller } from "@hotwired/stimulus"

// Formata e valida o CPF enquanto a pessoa digita: 1, 2, 3, 4 aparece como
// "123.4", e os 11 dígitos como "123.456.789-09". Pontos e traço são
// posicionados pelo controller; o que a pessoa digitar de separador é
// ignorado, e o que passar de 11 dígitos é descartado.
//
// O cursor é recolocado depois do mesmo número de dígitos em que estava, para
// corrigir um dígito no meio do CPF não jogar o cursor para o fim.
//
// A validação usa o mesmo módulo 11 do servidor (Seller#cpf_must_be_valid):
// com os 11 dígitos digitados, ou ao sair do campo, a mensagem aparece logo
// abaixo e o navegador não deixa enviar (setCustomValidity). Enquanto a
// pessoa ainda digita, um CPF incompleto não é cobrado.
//
// É conveniência, não a validação de verdade: o servidor guarda só os dígitos
// e valida de novo, então sem JavaScript o cadastro continua funcionando. A
// mesma máscara existe no servidor (Seller.format_cpf) para a tela de erro
// devolver o valor já formatado.
export default class extends Controller {
  static targets = ["input", "message"]

  connect() {
    if (this.inputTarget.value.trim() !== "") {
      this.format()
      this.validate()
    }
  }

  format() {
    const input = this.inputTarget
    const caret = input.selectionStart ?? input.value.length
    const digitsBeforeCaret = input.value.slice(0, caret).replace(/\D/g, "").length

    const digits = input.value.replace(/\D/g, "").slice(0, 11)
    input.value = this.mask(digits)

    if (document.activeElement === input) {
      const position = this.positionAfterDigits(input.value, digitsBeforeCaret)
      input.setSelectionRange(position, position)
    }

    if (digits.length === 11) {
      this.validate()
    } else {
      this.showMessage("")
    }
  }

  validate() {
    const digits = this.inputTarget.value.replace(/\D/g, "")
    this.showMessage(this.problemWith(digits))
  }

  problemWith(digits) {
    if (digits === "") return ""
    if (digits.length < 11) {
      const missing = 11 - digits.length
      return `O CPF tem 11 números. ${missing === 1 ? "Falta 1" : `Faltam ${missing}`}.`
    }
    if (!this.validChecksum(digits)) return "CPF inválido: os números não formam um CPF. Confira se algum foi digitado errado."
    return ""
  }

  showMessage(message) {
    this.inputTarget.setCustomValidity(message)
    this.inputTarget.setAttribute("aria-invalid", message ? "true" : "false")
    if (!this.hasMessageTarget) return

    this.messageTarget.textContent = message
    this.messageTarget.hidden = message === ""
  }

  // Módulo 11 sobre os 9 e depois os 10 primeiros dígitos; sequência de um
  // dígito só (111.111.111-11) passa na conta mas não é CPF.
  validChecksum(digits) {
    if (/^(\d)\1{10}$/.test(digits)) return false

    return [9, 10].every((length) => {
      const sum = digits
        .slice(0, length)
        .split("")
        .reduce((total, digit, index) => total + Number(digit) * (length + 1 - index), 0)
      const check = ((sum * 10) % 11) % 10
      return check === Number(digits[length])
    })
  }

  mask(digits) {
    const groups = [digits.slice(0, 3), digits.slice(3, 6), digits.slice(6, 9)].filter((group) => group !== "")
    const formatted = groups.join(".")
    return digits.length > 9 ? `${formatted}-${digits.slice(9)}` : formatted
  }

  positionAfterDigits(value, count) {
    if (count === 0) return 0

    let seen = 0
    for (let index = 0; index < value.length; index++) {
      if (/\d/.test(value[index])) seen++
      if (seen === count) return index + 1
    }
    return value.length
  }
}
