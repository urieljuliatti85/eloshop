class CancelExpiredOrdersJob < ApplicationJob
  queue_as :default

  def perform
    Orders::CancelExpired.new.call
    Orders::CancelAbandoned.new.call
  end
end
