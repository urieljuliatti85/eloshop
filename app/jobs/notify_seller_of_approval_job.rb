class NotifySellerOfApprovalJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(seller)
    recipient = seller.users.order(:created_at).first&.email_address
    return if recipient.blank?

    SellerLaunchMailer.approved(seller, recipient).deliver_now
  end
end
