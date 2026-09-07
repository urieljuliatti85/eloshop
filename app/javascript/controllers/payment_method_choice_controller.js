import { Controller } from "@hotwired/stimulus"

// Alterna a exibição do Card Payment Brick quando o cliente escolhe "cartão"
// na tela de pagamento. PIX continua submetendo direto (sem Brick).
//
// O Brick só é inserido no DOM ao clicar, não no carregamento da página: o
// SDK do Mercado Pago mede o container para montar seus iframes, e um
// elemento ainda oculto tem dimensão zero — o clone do <template> só entra
// depois que a seção já está visível.
export default class extends Controller {
  static targets = ["cardSection", "cardTemplate"]

  showCard() {
    if (this.cardSectionTarget.childElementCount > 0) return

    const content = this.cardTemplateTarget.content.cloneNode(true)
    this.cardSectionTarget.appendChild(content)
  }
}
