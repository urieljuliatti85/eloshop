module Carts
  # Manda no máximo UM lembrete por período de abandono a quem deixou itens no
  # carrinho. Só alcança cliente logado: é o login que liga o carrinho a um
  # e-mail (carrinho anônimo não tem para onde ir).
  #
  # Regras (decisão do negócio, 2026-10-01): 24 horas depois da última mudança
  # no carrinho, sem cupom, com descadastro em todo e-mail. Não manda se o
  # cliente já comprou depois disso, se recusou os lembretes, se nenhum item
  # pode mais ser comprado, ou se o carrinho está parado há mais de 7 dias
  # (evita e-mail velho depois de uma pausa do job).
  class SendReminders
    IDLE_FOR = 24.hours
    GIVE_UP_AFTER = 7.days

    def call
      candidate_carts.find_each { |cart| remind(cart) }
    end

    private

    def candidate_carts
      Cart.joins(:customer).merge(Customer.where(cart_reminder_emails: true))
        .where(id: idle_cart_ids)
    end

    def idle_cart_ids
      CartItem.group(:cart_id)
        .having("MAX(cart_items.updated_at) <= ? AND MAX(cart_items.updated_at) >= ?", IDLE_FOR.ago, GIVE_UP_AFTER.ago)
        .select(:cart_id)
    end

    def remind(cart)
      claimed = cart.with_lock { claim?(cart) }
      CartReminderMailer.reminder(cart).deliver_later if claimed
    end

    # Marca o lembrete como enviado ANTES de enfileirar o e-mail, dentro do lock:
    # duas rodadas concorrentes não mandam duas vezes, e uma falha de entrega é
    # repetida pelo próprio job de e-mail sem voltar a esta decisão.
    def claim?(cart)
      last_activity = cart.cart_items.maximum(:updated_at)
      return false unless last_activity
      return false if cart.reminder_sent_at && cart.reminder_sent_at >= last_activity
      return false if cart.customer.orders.where(created_at: last_activity..).exists?
      return false if cart.remindable_items.empty?

      cart.update!(reminder_sent_at: Time.current)
      true
    end
  end
end
