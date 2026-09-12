import { Controller } from "@hotwired/stimulus"

// Monta o Card Payment Brick do Mercado Pago para tokenizar o cartão no
// navegador — nenhum dado sensível (número, CVV) chega ao backend, só o
// token gerado aqui. O SDK (window.MercadoPago) é carregado por uma tag
// <script> separada na view, porque não é um módulo ES compatível com
// importmap; este controller só assume que já está disponível ao conectar.
export default class extends Controller {
  static values = { publicKey: String, amount: Number, formUrl: String, cspNonce: String }
  static targets = ["container", "error"]

  connect() {
    this.render()
  }

  async render() {
    if (typeof window.MercadoPago === "undefined") {
      this.showError("Não foi possível carregar o formulário de cartão. Recarregue a página.")
      return
    }

    // A API do Brick exige o id (string) do container, não o elemento — o
    // template clonado não traz id, então este controller atribui um.
    if (!this.containerTarget.id) {
      this.containerTarget.id = `card-payment-brick-${Math.random().toString(36).slice(2)}`
    }

    // `deviceProfileCspNonce` é opção do próprio SDK: ele injeta em runtime
    // um <script> inline com o widget antifraude (device profile) e aplica
    // este nonce nele. Sem isso a CSP bloqueia o script — o Brick fica preso
    // no skeleton e o antifraude não roda. A alternativa seria `unsafe-inline`
    // em `script-src`, que desligaria a proteção contra XSS justamente na
    // tela onde o cliente digita o cartão. Mesmo padrão já visto no `style-src`
    // (2026-09-07), onde o SDK também injeta sem nonce — lá não havia opção.
    const mp = new window.MercadoPago(this.publicKeyValue, {
      locale: "pt-BR",
      deviceProfileCspNonce: this.cspNonceValue
    })
    const bricksBuilder = mp.bricks()

    await bricksBuilder.create("cardPayment", this.containerTarget.id, {
      initialization: { amount: this.amountValue },
      callbacks: {
        onSubmit: (cardFormData) => this.submitToken(cardFormData),
        onError: (error) => this.showError(error?.message || "Não foi possível processar o cartão.")
      }
    })
  }

  async submitToken(cardFormData) {
    this.hideError()

    const response = await fetch(this.formUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "text/vnd.turbo-stream.html, text/html",
        "X-CSRF-Token": this.csrfToken()
      },
      credentials: "same-origin",
      body: JSON.stringify({
        payment_method: "credit_card",
        card_token: cardFormData.token,
        installments: cardFormData.installments
      })
    })

    if (response.redirected) {
      window.location = response.url
      return
    }

    this.showError("Não foi possível processar o cartão. Tente novamente.")
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  hideError() {
    this.errorTarget.hidden = true
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
