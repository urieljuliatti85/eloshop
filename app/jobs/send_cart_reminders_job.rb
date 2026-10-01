class SendCartRemindersJob < ApplicationJob
  queue_as :default

  def perform
    Carts::SendReminders.new.call
  end
end
