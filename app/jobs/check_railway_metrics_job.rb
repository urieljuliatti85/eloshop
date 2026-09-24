class CheckRailwayMetricsJob < ApplicationJob
  queue_as :default

  def perform
    Observability::RailwayAlertCheck.new.call
  end
end
