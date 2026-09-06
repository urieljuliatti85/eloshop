import { Controller } from "@hotwired/stimulus"

// Preenche rua, bairro, cidade e UF ao digitar um CEP completo. Consulta o
// próprio backend (SellerPortal::PostalCodesController), nunca a API de CEP
// direto do navegador — a CSP restringe connect_src a :self.
export default class extends Controller {
  static targets = ["zipCode", "street", "neighborhood", "city", "state"]
  static values = { url: String }

  lookup() {
    const digits = this.zipCodeTarget.value.replace(/\D/g, "")
    if (digits.length !== 8) return

    fetch(this.urlValue.replace("00000000", digits), {
      headers: { Accept: "application/json" }
    })
      .then((response) => (response.ok ? response.json() : null))
      .then((address) => {
        if (!address) return

        this.streetTarget.value = address.street
        this.neighborhoodTarget.value = address.neighborhood
        this.cityTarget.value = address.city
        this.stateTarget.value = address.state
      })
      .catch(() => {})
  }
}
