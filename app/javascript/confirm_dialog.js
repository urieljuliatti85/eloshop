// Confirmação dos botões e links com `data-turbo-confirm` (`turbo_confirm:`
// nas views) num <dialog> da própria página, no lugar do window.confirm.
//
// Por quê: em navegador de aplicativo (Instagram, Facebook, às vezes
// WhatsApp) e no Chrome com "não permitir mais caixas de diálogo", o
// window.confirm responde "não" sem aparecer — e o botão simplesmente não
// fazia nada (remover variante, cancelar pedido, desconectar...).
//
// O <dialog> usa <form method="dialog">: os botões fecham o dialog com
// `returnValue` sem nenhum handler, Esc conta como "Cancelar", e o foco
// começa no "Cancelar" (a escolha segura) e volta a quem abriu. A mensagem
// entra por `textContent`, nunca como HTML. Navegador sem <dialog> cai no
// window.confirm de antes.
//
// Duas proteções que o window.confirm tinha de graça, por travar a página
// (achadas no /qa de 2026-11-02):
// - Duplo toque: o "Confirmar" abre exatamente sob o dedo em botões no meio
//   da tela, e o segundo toque confirmava sem a pessoa ler. Por isso ele
//   ignora toques nos primeiros CONFIRM_GUARD_MS depois de abrir.
// - Voltar/avançar: a página voltava com o dialog aberto, e o "Confirmar"
//   concluía a ação pendente de antes. Duas memórias guardam a página: a do
//   Turbo (navegação pelo Turbo, evento `turbo:before-cache`) e a do próprio
//   navegador (back/forward cache, depois de um carregamento completo, evento
//   `pagehide`, com o JavaScript ainda vivo). Nas duas, o dialog é
//   descartado como "Cancelar" antes de a página ser guardada.
const CONFIRM_GUARD_MS = 400

export function confirmDialog(message) {
  if (typeof HTMLDialogElement !== "function") return Promise.resolve(window.confirm(message))

  return new Promise((resolve) => {
    const opener = document.activeElement
    const dialog = buildDialog(message)
    const confirmButton = dialog.querySelector("button[value='confirm']")
    let settled = false

    // Termina uma vez só, seja qual for o caminho (botão, Esc, fundo, saída).
    const finish = (confirmed, { restoreFocus = true } = {}) => {
      if (settled) return
      settled = true
      document.removeEventListener("turbo:before-cache", discard)
      window.removeEventListener("pagehide", discard)
      resolve(confirmed)
      dialog.remove()
      if (restoreFocus && opener instanceof HTMLElement && opener.isConnected) opener.focus({ preventScroll: true })
    }
    const discard = () => finish(false, { restoreFocus: false })

    dialog.addEventListener("close", () => finish(dialog.returnValue === "confirm"), { once: true })
    document.addEventListener("turbo:before-cache", discard)
    window.addEventListener("pagehide", discard)

    // Clique no fundo (fora do cartão) também cancela.
    dialog.addEventListener("click", (event) => {
      if (event.target === dialog) dialog.close("cancel")
    })

    // `data-ready` marca o fim da proteção (os testes esperam por ele).
    setTimeout(() => { dialog.dataset.ready = "" }, CONFIRM_GUARD_MS)
    confirmButton.addEventListener("click", (event) => {
      if (!("ready" in dialog.dataset)) event.preventDefault()
    })

    document.body.append(dialog)
    dialog.showModal()
  })
}

function buildDialog(message) {
  const dialog = element("dialog", "m-auto w-[min(28rem,calc(100vw-2rem))] rounded-2xl border border-stone-200 bg-white p-0 text-stone-900 shadow-2xl backdrop:bg-stone-950/60")
  dialog.setAttribute("aria-labelledby", "confirm-dialog-message")
  dialog.dataset.confirmDialog = ""

  const form = element("form", "grid gap-5 p-5 sm:p-6")
  form.method = "dialog"

  const text = element("p", "text-base leading-6 font-semibold")
  text.id = "confirm-dialog-message"
  text.textContent = message

  const actions = element("div", "flex flex-col-reverse gap-3 sm:flex-row sm:justify-end")
  const cancel = button("Cancelar", "cancel", "border border-stone-300 bg-white text-stone-800 hover:bg-stone-50")
  cancel.autofocus = true
  const confirm = button("Confirmar", "confirm", "bg-brand-600 text-white hover:bg-brand-700")
  actions.append(cancel, confirm)

  form.append(text, actions)
  dialog.append(form)
  return dialog
}

function button(label, value, colors) {
  const node = element("button", `inline-flex min-h-11 items-center justify-center rounded-full px-5 text-sm font-semibold transition focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-brand-500 ${colors}`)
  node.type = "submit"
  node.value = value
  node.textContent = label
  return node
}

function element(tag, className) {
  const node = document.createElement(tag)
  node.className = className
  return node
}
