import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["address", "shipping", "total"]
  static values = { subtotal: Number }

  connect() {
    this.update()
  }

  update() {
    const selected = this.addressTargets.find((address) => address.checked)
    if (!selected) return

    const shippingCents = Number(selected.dataset.shippingCents)
    this.shippingTarget.textContent = this.currency(shippingCents)
    this.totalTarget.textContent = this.currency(this.subtotalValue + shippingCents)
  }

  currency(cents) {
    return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(cents / 100)
  }
}
