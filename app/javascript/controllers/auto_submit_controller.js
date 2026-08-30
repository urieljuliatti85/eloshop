import { Controller } from "@hotwired/stimulus"

// Envia o formulário assim que um controle muda — usado nos seletores
// "Mostrar" e "Ordenar por" da vitrine, que não têm botão visível.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
