class ReconcilePaymentsJob < ApplicationJob
  queue_as :default

  def perform
    Payments::Reconcile.new.call
  end
end
