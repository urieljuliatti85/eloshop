module ShippingLabels
  # O que impede comprar uma etiqueta agora. Roda com o SellerOrder travado,
  # o mesmo lock de "marcar como enviado" e do reembolso (Shipment#transition_to!,
  # Payments::Refund): desistência aberta ou reembolso integral em andamento
  # bloqueiam a compra, e a etiqueta já comprada não é cancelada sozinha —
  # decisão do Uriel de 2026-11-05 (ADR 005).
  module Guard
    module_function

    # Devolve a mensagem para o ateliê, ou nil quando pode comprar.
    def blocker(shipment)
      seller_order = shipment.seller_order
      return "O pedido precisa estar pago e aguardando envio para gerar a etiqueta." unless shipment.awaiting_dispatch?
      return "Há um reembolso integral em andamento neste pedido; não gere a etiqueta." if seller_order.full_refund_in_progress?

      if (withdrawal = seller_order.return_requests.open.kind_withdrawal.first)
        return "O comprador pediu para desistir da compra (#{withdrawal.protocol}); não gere a etiqueta. A EloShop vai responder e avisar se o envio voltar a valer."
      end

      nil
    end

    # Pré-condições que não dependem do lock: conta, dados do pedido e do ateliê.
    def account_blocker(seller, order)
      return "A geração de etiquetas ainda não está liberada." unless ShippingLabels.enabled?
      return "Conecte a sua conta SuperFrete para gerar etiquetas." unless seller.superfrete_ready?
      return account_mismatch_message unless account_bound?(seller)
      return "Este pedido não tem o CPF de quem recebe, que a etiqueta exige. Gere a etiqueta no site da SuperFrete." if order.recipient_cpf.blank?
      return "Complete o endereço de origem e o nome do responsável em Dados do Ateliê para gerar etiquetas." unless sender_complete?(seller)

      nil
    end

    # Golpe de consentimento do OAuth (ADR 005, "Condição de segurança para a
    # Etapa 2"): a conta SuperFrete conectada tem de ser de alguém do ateliê.
    # Sem isso, quem convencesse outra pessoa a autorizar pelo link dele
    # compraria etiquetas com a carteira dela.
    def account_bound?(seller)
      email = seller.superfrete_account_email.to_s.strip.downcase
      email.present? && seller.users.exists?(email_address: email)
    end

    def account_mismatch_message
      "A conta SuperFrete conectada precisa usar o mesmo e-mail do seu acesso ao painel da EloShop. " \
        "Conecte a SuperFrete com a conta desse e-mail para gerar etiquetas por aqui."
    end

    def sender_complete?(seller)
      %i[origin_zip_code origin_street origin_number origin_neighborhood origin_city origin_state].all? { |field| seller.public_send(field).present? } &&
        (seller.owner_full_name.presence || seller.name).to_s.split.size >= 2
    end
  end
end
