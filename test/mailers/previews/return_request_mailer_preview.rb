# Preview all emails at http://localhost:3000/rails/mailers/return_request_mailer
#
# Só renderiza no navegador; nada é enviado. Usa a solicitação mais recente do
# banco local, se houver; senão monta uma em memória sobre um pedido
# existente, sem gravar nada.
class ReturnRequestMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/return_request_mailer/opened
  def opened
    ReturnRequestMailer.opened(return_request)
  end

  # Preview this email at http://localhost:3000/rails/mailers/return_request_mailer/updated
  def updated
    request = return_request
    update = request.updates.where(author_type: "User").order(:created_at).last ||
      ReturnRequestUpdate.new(
        return_request: request,
        author: User.admin.take || User.new,
        body: "Recebemos a sua desistência e já solicitamos o reembolso integral, com o frete. " \
              "O valor aparece conforme o prazo do seu banco ou cartão.",
        from_status: "received",
        to_status: "in_progress",
        created_at: Time.current
      )
    ReturnRequestMailer.updated(update)
  end

  # Preview this email at http://localhost:3000/rails/mailers/return_request_mailer/seller_notice
  def seller_notice
    request = return_request
    ReturnRequestMailer.seller_notice(
      request, "atelie@eloshop.test", "Desistência no pedido ##{request.order.id}",
      "O comprador pediu para desistir do pedido ##{request.order.id} (#{request.protocol}). Não envie a peça: a EloShop vai responder ao comprador."
    )
  end

  private

  def return_request
    ReturnRequest.order(:created_at).last || sample_return_request
  end

  def sample_return_request
    order = Order.joins(:seller_orders).take or
      raise "Sem pedidos no banco local: rode bin/rails db:seed e faça uma compra antes de abrir a preview."

    ReturnRequest.new(
      id: 0,
      seller_order: order.seller_orders.first,
      kind: "withdrawal",
      status: "received",
      protocol: "ELO-#{Date.current.year}-000123",
      description: "Mudei de ideia e não quero mais a peça.",
      respond_by: ReturnRequest.respond_by_for(Time.current),
      created_at: Time.current
    ).tap { |request| request.define_singleton_method(:order) { order } }
  end
end
