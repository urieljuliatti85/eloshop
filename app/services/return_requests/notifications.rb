module ReturnRequests
  # Avisos de toda movimentação de uma solicitação pós-venda (ADR 008), num
  # lugar só. Regra: cada movimentação avisa todos os envolvidos — comprador,
  # ateliê e admins — menos quem agiu. A exceção é a abertura, que também vai
  # ao comprador, porque leva o protocolo.
  #
  # Sempre depois do commit, e cada aviso por conta própria
  # (ReturnRequests.deliver_safely): a falha de um vai para o Sentry sem
  # derrubar os outros nem a resposta. Comprador e ateliê recebem e-mail e
  # notificação; admins, a notificação do painel.
  class Notifications
    def self.opened(return_request) = new(return_request).opened
    def self.customer_message(return_request) = new(return_request).customer_message
    def self.updated(update) = new(update.return_request).updated(update)

    def initialize(return_request)
      @return_request = return_request
      @seller_order = return_request.seller_order
      @order = return_request.order
    end

    # O comprador abriu a solicitação.
    def opened
      safely { ReturnRequestMailer.opened(@return_request).deliver_later }
      notify_customer(
        kind: :return_request_opened,
        title: "Solicitação #{protocol} recebida",
        body: "#{kind_label} no pedido ##{@order.id}. A EloShop responde até #{respond_by}."
      )
      notify_admins(
        kind: :return_request_opened,
        title: "Nova solicitação #{protocol}",
        body: "#{kind_label} no pedido ##{@order.id}. Responder até #{respond_by}."
      )
      notify_seller(
        kind: :return_request_opened,
        title: @return_request.kind_withdrawal? ? "Desistência no pedido ##{@order.id}" : "Solicitação no pedido ##{@order.id}",
        body: opened_seller_message
      )
    end

    # O comprador acrescentou informação a uma solicitação aberta.
    def customer_message
      notify_admins(
        title: "Nova mensagem em #{protocol}",
        body: "O comprador acrescentou informação à solicitação do pedido ##{@order.id}."
      )
      notify_seller(
        title: "Nova mensagem em #{protocol}",
        body: "O comprador acrescentou informação à solicitação do pedido ##{@order.id} (#{kind_label.downcase}). A EloShop vai responder a ele."
      )
    end

    # Um admin respondeu e/ou mudou a situação.
    def updated(update)
      safely { ReturnRequestMailer.updated(update).deliver_later }
      notify_customer(
        title: "Solicitação #{protocol} atualizada",
        body: update.status_change? ? "Situação: #{status_label}." : "A EloShop respondeu à sua solicitação."
      )
      notify_seller(title: "Solicitação #{protocol} #{update.status_change? ? status_label.downcase : 'atualizada'}", body: updated_seller_message(update))
      notify_admins(
        title: "Solicitação #{protocol} atualizada",
        body: "#{update.author.email_address} #{admin_action(update)} na solicitação do pedido ##{@order.id}.",
        except: update.author
      )
    end

    private

    def notify_customer(title:, body:, kind: :return_request_updated)
      safely do
        Notification.create!(recipient: @order.customer, kind: kind, title: title, body: body,
          url: url_helpers.order_return_request_path(@order, @return_request))
      end
    end

    # Painel e e-mail: o ateliê precisa saber, por exemplo, que não deve
    # enviar a peça. O e-mail vai para o primeiro usuário do ateliê, como o de
    # nova venda (NotifySellerOfOrderJob); ateliê sem usuário fica só no painel.
    def notify_seller(title:, body:, kind: :return_request_updated)
      safely do
        Notification.create!(recipient: @seller_order.seller, kind: kind, title: title, body: body,
          url: url_helpers.seller_order_path(@order))
      end
      recipient = @seller_order.seller.users.order(:created_at).first&.email_address
      return if recipient.blank?

      safely { ReturnRequestMailer.seller_notice(@return_request, recipient, title, body).deliver_later }
    end

    # Cada admin tem sua própria linha (para marcar como lida), como em
    # Notification.notify_admins!, mas sem avisar quem agiu.
    def notify_admins(title:, body:, kind: :return_request_updated, except: nil)
      safely do
        admins = User.admin
        admins = admins.where.not(id: except.id) if except.is_a?(User)
        admins.find_each do |admin|
          Notification.create!(recipient: admin, kind: kind, title: title, body: body,
            url: url_helpers.admin_return_request_path(@return_request))
        end
      end
    end

    def opened_seller_message
      if @return_request.kind_withdrawal? && not_shipped?
        "O comprador pediu para desistir do pedido ##{@order.id} (#{protocol}). Não envie a peça: a EloShop vai responder ao comprador."
      else
        "O comprador abriu a solicitação #{protocol} (#{kind_label.downcase}) no pedido ##{@order.id}. A EloShop vai responder ao comprador."
      end
    end

    def updated_seller_message(update)
      unless update.status_change?
        return "A EloShop respondeu ao comprador na solicitação do pedido ##{@order.id} (#{kind_label.downcase})."
      end

      message = "A EloShop mudou a solicitação do pedido ##{@order.id} (#{kind_label.downcase}) para \"#{status_label}\"."
      if @return_request.kind_withdrawal? && !@return_request.open? && not_shipped?
        message += " O envio está liberado."
      end
      message
    end

    def admin_action(update)
      return "respondeu ao comprador e mudou a situação para \"#{status_label}\"" if update.status_change? && update.body.present?
      return "mudou a situação para \"#{status_label}\"" if update.status_change?

      "respondeu ao comprador"
    end

    def not_shipped?
      @seller_order.shipment.nil? || @seller_order.shipment.pending?
    end

    def safely(&block)
      ReturnRequests.deliver_safely(@return_request, &block)
    end

    def protocol = @return_request.protocol
    def kind_label = @return_request.kind_label
    def status_label = @return_request.status_label
    def respond_by = I18n.l(@return_request.respond_by, format: :short)
    def url_helpers = Rails.application.routes.url_helpers
  end
end
