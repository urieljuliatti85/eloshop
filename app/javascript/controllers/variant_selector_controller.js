import { Controller } from "@hotwired/stimulus"

// Seletor de variante (tamanho/cor/material) na página do produto. Troca de
// preço/estoque acontece inteiramente no cliente — os dados de todas as
// variantes ativas já vêm embutidos na página, sem round-trip ao servidor.
// O servidor sempre revalida a variante escolhida no carrinho e no checkout.
//
// Cada dimensão (tamanho/cor/material) é um grupo de radio buttons
// estilizados como chips — por isso lemos o valor do item marcado
// (checkedValue), não de um único target como um <select> faria.
export default class extends Controller {
  static targets = ["size", "color", "material", "price", "stockNotice", "variantId", "submit"]
  static values = { variants: Array }

  connect() {
    this.update()
  }

  update() {
    const variant = this.findVariant()

    if (variant) {
      this.variantIdTarget.value = variant.id
      this.priceTarget.textContent = variant.formattedPrice
    } else {
      this.variantIdTarget.value = ""
    }

    this.stockNoticeTarget.textContent = this.noticeFor(variant)
    this.submitTarget.disabled = !variant || variant.stockQuantity <= 0
  }

  findVariant() {
    return this.variantsValue.find((variant) => {
      if (this.hasSizeTarget && variant.size !== this.checkedValue(this.sizeTargets)) return false
      if (this.hasColorTarget && variant.color !== this.checkedValue(this.colorTargets)) return false
      if (this.hasMaterialTarget && variant.material !== this.checkedValue(this.materialTargets)) return false

      return true
    })
  }

  checkedValue(targets) {
    return targets.find((el) => el.checked)?.value
  }

  noticeFor(variant) {
    if (!variant) return "Combinação indisponível."
    if (variant.stockQuantity <= 0) return "Sem estoque para esta combinação."

    return ""
  }
}
