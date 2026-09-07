import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["address", "shippingOption", "shipping", "total"]
  static values = { subtotal: Number }

  connect() {
    this.update()
  }

  // As opções de frete são cotadas por CEP: trocar de endereço invalida a
  // modalidade escolhida, e manter a marcação mostraria um preço que não
  // corresponde ao destino. A recotação em si acontece no servidor, que
  // recusa uma opção que não está mais entre as ofertadas.
  selectAddress() {
    this.shippingOptionTargets.forEach((option, index) => {
      option.checked = index === 0
    })
    this.update()
  }

  update() {
    const shippingCents = this.selectedShippingCents()
    if (shippingCents === null) return

    this.shippingTarget.textContent = this.currency(shippingCents)
    this.totalTarget.textContent = this.currency(this.subtotalValue + shippingCents)
  }

  // A modalidade escolhida manda quando existe; o endereço só carrega a opção
  // mais barata, que é o resumo exibido na lista.
  selectedShippingCents() {
    const selected =
      this.shippingOptionTargets.find((option) => option.checked) ||
      this.addressTargets.find((address) => address.checked)

    return selected ? Number(selected.dataset.shippingCents) : null
  }

  currency(cents) {
    return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(cents / 100)
  }
}
