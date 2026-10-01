class CartReminderMailer < ApplicationMailer
  # Lembrete de carrinho esquecido. Recalcula os itens no envio: o e-mail pode
  # sair horas depois da decisão, e um item que saiu do ar não deve aparecer.
  def reminder(cart)
    @cart = cart
    @customer = cart.customer
    @items = cart.remindable_items
    return if @items.empty?

    @unsubscribe_url = cart_reminder_unsubscribe_url(token: @customer.generate_token_for(:cart_reminder_unsubscribe))
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"

    mail(to: @customer.email, subject: "Você deixou itens no carrinho — EloShop")
  end
end
