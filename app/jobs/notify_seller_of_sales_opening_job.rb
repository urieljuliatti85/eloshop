class NotifySellerOfSalesOpeningJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(seller)
    recipient = seller.users.order(:created_at).first&.email_address
    return if recipient.blank?

    # Decidido na execução, não no enfileiramento: quem foi aprovado entre um
    # e outro já recebe o convite para divulgar.
    if seller.approved?
      SellerLaunchMailer.sales_opened(seller, recipient).deliver_now
    else
      SellerLaunchMailer.sales_opened_not_accepting_orders(seller, recipient).deliver_now
    end
  end
end
