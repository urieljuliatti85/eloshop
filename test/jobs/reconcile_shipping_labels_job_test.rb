require "test_helper"

class ReconcileShippingLabelsJobTest < ActiveJob::TestCase
  include ShippingLabelTestHelper

  setup do
    prepare_label_scenario
    @client = FakeClient.new
    @label = build_label(status: :purchased, purchased_at: 2.days.ago)
  end

  test "applies what SuperFrete reports for labels still in transit and registers the missing webhook" do
    @client.info_result = @client.info(status: "posted", tracking: "AA123456789BR")

    with_fake_client do
      assert_enqueued_with(job: RegisterSuperfreteWebhookJob, args: [ @seller ]) do
        ReconcileShippingLabelsJob.perform_now
      end
    end

    assert @shipment.reload.shipped?
    assert_equal "AA123456789BR", @shipment.tracking_code
  end

  test "skips labels already delivered, too old, or from another account" do
    @label.update_columns(delivered_at: Time.current)
    with_fake_client { ReconcileShippingLabelsJob.perform_now }
    assert_not @client.called?(:order_info)

    @label.update_columns(delivered_at: nil, purchased_at: 61.days.ago)
    with_fake_client { ReconcileShippingLabelsJob.perform_now }
    assert_not @client.called?(:order_info)

    @label.update_columns(purchased_at: 1.day.ago, superfrete_account_id: "other-account")
    with_fake_client { ReconcileShippingLabelsJob.perform_now }
    assert_not @client.called?(:order_info)
  end

  test "a SuperFrete failure on one label does not stop the run" do
    @client.info_result = ShippingLabels::Client::Ambiguous.new("timeout")

    with_fake_client do
      assert_nothing_raised { ReconcileShippingLabelsJob.perform_now }
    end
    assert @shipment.reload.pending?
  end

  test "does nothing with labels off" do
    Rails.configuration.x.shipping.labels_enabled = false
    with_fake_client { ReconcileShippingLabelsJob.perform_now }
    assert_empty @client.calls
  ensure
    Rails.configuration.x.shipping.labels_enabled = true
  end

  private

  def with_fake_client
    original = ShippingLabels.method(:client_for)
    client = @client
    ShippingLabels.define_singleton_method(:client_for) { |*, **| client }
    yield
  ensure
    ShippingLabels.define_singleton_method(:client_for, original)
  end
end
