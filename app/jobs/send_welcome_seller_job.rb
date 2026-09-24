class SendWelcomeSellerJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(seller, recipient)
    WelcomeMailer.welcome_seller(seller, recipient).deliver_now
  end
end
