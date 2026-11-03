module ReturnRequests
  # Abre uma solicitação pós-venda pelo comprador (ADR 008, Fase 1) e devolve
  # o protocolo na hora — a confirmação imediata do Decreto 7.962 é a da tela;
  # o e-mail sai depois do commit e a falha dele não desfaz nada.
  #
  # Nunca recusa por prazo de desistência nem por produção iniciada (parecer
  # de 2026-10-29). Só exige pedido pago e ainda não reembolsado por inteiro.
  #
  # Trava o SellerOrder, o mesmo lock que Shipment#transition_to! toma antes de
  # marcar o envio: ou a desistência entra primeiro e o envio é recusado, ou o
  # envio entra primeiro e a desistência fica registrada como pós-envio. Ordem
  # de travas Payment → SellerOrder → ReturnRequest (ADR 008, regra 3).
  class Open
    class NotEligible < StandardError; end

    Result = Data.define(:return_request, :created)

    def initialize(seller_order:, customer:, kind:, description: nil)
      @seller_order = seller_order
      @customer = customer
      @kind = kind.to_s
      @description = description.to_s.strip.presence
    end

    def call
      raise NotEligible, "escolha o motivo da solicitação" unless ReturnRequest.kinds.key?(@kind)

      result = ActiveRecord::Base.transaction do
        @seller_order.lock!
        raise NotEligible, "só é possível abrir uma solicitação para pedido pago" unless ReturnRequest.eligible?(@seller_order)

        existing = @seller_order.return_requests.open.find_by(kind: @kind)
        existing ? add_to_existing(existing) : create_request
      end
      notify(result) if result.created
      result
    end

    private

    # Já há uma solicitação aberta deste tipo: a nova mensagem entra no
    # histórico dela (o índice único parcial impede outra aberta).
    def add_to_existing(return_request)
      return_request.updates.create!(author: @customer, body: @description) if @description
      Result.new(return_request: return_request, created: false)
    end

    def create_request
      return_request = @seller_order.return_requests.create!(
        kind: @kind,
        description: @description,
        respond_by: ReturnRequest.respond_by_for(Time.current)
      )
      # Fase 1: sempre o pedido inteiro (decisão B sem custo de tela).
      @seller_order.order_items.each do |item|
        return_request.items.create!(order_item: item, quantity: item.quantity)
      end
      return_request.updates.create!(author: @customer, body: @description, to_status: "received")
      return_request.reload # o protocolo é gerado pelo banco
      OrderEvent.create!(
        order: @seller_order.order,
        kind: :return_request_opened,
        status: @seller_order.order.status,
        metadata: { return_request_id: return_request.id, protocol: return_request.protocol, kind: @kind }
      )
      # Duas abas abrindo ao mesmo tempo ficam em fila no lock do SellerOrder,
      # e a segunda cai em `add_to_existing`; o índice único parcial é a
      # garantia no banco caso algum caminho futuro esqueça o lock.
      Result.new(return_request: return_request, created: true)
    end

    def notify(result)
      return_request = result.return_request
      order = @seller_order.order
      url_helpers = Rails.application.routes.url_helpers

      ReturnRequestMailer.opened(return_request).deliver_later
      Notification.notify_admins!(
        kind: :return_request_opened,
        title: "Nova solicitação #{return_request.protocol}",
        body: "#{return_request.kind_label} no pedido ##{order.id}. Responder até #{I18n.l(return_request.respond_by, format: :short)}.",
        url: url_helpers.admin_return_request_path(return_request)
      )
      Notification.create!(
        recipient: @seller_order.seller,
        kind: :return_request_opened,
        title: return_request.kind_withdrawal? ? "Desistência no pedido ##{order.id}" : "Solicitação no pedido ##{order.id}",
        body: seller_message(return_request, order),
        url: url_helpers.seller_order_path(order)
      )
    end

    def seller_message(return_request, order)
      not_shipped = @seller_order.shipment.nil? || @seller_order.shipment.pending?
      if return_request.kind_withdrawal? && not_shipped
        "O comprador pediu para desistir do pedido ##{order.id} (#{return_request.protocol}). Não envie a peça: a EloShop vai responder ao comprador."
      else
        "O comprador abriu a solicitação #{return_request.protocol} (#{return_request.kind_label.downcase}) no pedido ##{order.id}. A EloShop vai responder ao comprador."
      end
    end
  end
end
