import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["address", "optionGroup", "shippingOption", "shipping", "total"]
  static values = { subtotal: Number }

  connect() {
    this.update()
  }

  // As opções de frete são cotadas por CEP, e cada endereço tem o próprio
  // grupo: trocar de endereço mostra o grupo dele e desabilita os outros, para
  // que só a modalidade do destino escolhido seja enviada. A recotação em si
  // acontece no servidor, que recusa uma opção que não está mais entre as
  // ofertadas.
  selectAddress() {
    const address = this.addressTargets.find((target) => target.checked)

    this.optionGroupTargets.forEach((group) => {
      const active = group.dataset.addressId === address?.value
      group.hidden = !active
      group.querySelectorAll("input").forEach((input, index) => {
        input.disabled = !active
        if (active && input.type === "radio") input.checked = index === 0
      })
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
      this.shippingOptionTargets.find((option) => option.checked && !option.disabled) ||
      this.addressTargets.find((address) => address.checked)

    return selected ? Number(selected.dataset.shippingCents) : null
  }

  currency(cents) {
    return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(cents / 100)
  }
}
