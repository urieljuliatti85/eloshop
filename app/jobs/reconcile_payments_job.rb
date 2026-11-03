class ReconcilePaymentsJob < ApplicationJob
  queue_as :default

  # Cobranças e reembolsos são reconciliados no mesmo agendamento; cada um
  # trata as próprias falhas por registro, então um não impede o outro.
  def perform
    Payments::Reconcile.new.call
    Payments::ReconcileRefunds.new.call
  end
end
