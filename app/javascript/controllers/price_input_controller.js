import { Controller } from "@hotwired/stimulus"

// Formata o preço em reais enquanto a pessoa digita: 4, 0, 0, 0 aparece como
// "0,04", "0,40", "4,00", "40,00".
//
// Os dígitos entram pela direita, como numa caixa registradora, e o cursor
// fica sempre no fim. É o que evita o problema de formatar a cada tecla:
// reescrever o valor moveria o cursor de qualquer forma, então o campo assume
// isso em vez de tentar preservar uma posição no meio do número. É também
// como se comportam os aplicativos de banco.
//
// Só dígitos importam — o que a pessoa digitar de separador é ignorado, já
// que a vírgula é posicionada pelo próprio controller.
//
// É conveniência de digitação, não validação. O servidor (MoneyAttribute)
// aceita "40", "40.00" e "R$ 1.299,90" e converte sozinho, então sem
// JavaScript o cadastro continua funcionando.
export default class extends Controller {
  connect() {
    // Um valor vindo do servidor (tela de edição) já chega formatado; o
    // reformat aqui cobre o caso de o navegador restaurar um rascunho.
    if (this.element.value.trim() !== "") this.render(this.centsFrom(this.element.value))
  }

  // Vírgula e ponto são descartados na leitura, então digitá-los não avança
  // casa nenhuma — a posição decimal vem da quantidade de dígitos.
  format() {
    this.render(this.centsFrom(this.element.value))
  }

  // Campo vazio continua vazio: um preço opcional não preenchido não pode
  // virar "0,00", que é um valor decidido.
  render(cents) {
    if (cents === null) {
      this.element.value = ""
      return
    }

    this.element.value = (cents / 100).toLocaleString("pt-BR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })

    // Depois de reescrever o valor, o cursor pode ir parar em qualquer lugar
    // dependendo do navegador. Fixa no fim, que é de onde o próximo dígito
    // entra.
    const end = this.element.value.length
    this.element.setSelectionRange(end, end)
  }

  centsFrom(value) {
    const digits = value.replace(/\D/g, "")
    if (digits === "") return null

    // Sem limite de casas: parseInt em string longa perderia precisão, mas
    // o campo é de preço e o servidor valida o resto.
    return Number(digits.slice(0, 15))
  }
}
