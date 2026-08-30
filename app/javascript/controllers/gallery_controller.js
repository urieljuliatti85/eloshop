import { Controller } from "@hotwired/stimulus"

// Troca a imagem principal da PDP ao clicar numa miniatura — só troca o
// src no cliente, sem round-trip ao servidor.
export default class extends Controller {
  static targets = ["main"]

  show(event) {
    this.mainTarget.src = event.params.src
  }
}
