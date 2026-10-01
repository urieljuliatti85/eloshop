class SellerFraudScanJob < ApplicationJob
  queue_as :default

  def perform
    Fraud::Notifier.call(Fraud::SellerScan.new.call)
  end
end
