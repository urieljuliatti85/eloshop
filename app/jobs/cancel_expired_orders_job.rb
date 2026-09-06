class CancelExpiredOrdersJob < ApplicationJob
  queue_as :default

  def perform
    Orders::CancelExpired.new.call
  end
end
