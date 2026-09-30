require "test_helper"

class SellerFraudScanJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @seller = sellers(:approved)
    @seller.update!(
      mercado_pago_user_id: "u1", mercado_pago_access_token_ciphertext: "x", mercado_pago_refresh_token_ciphertext: "y",
      mercado_pago_connected_at: Time.current, mercado_pago_live_mode: true, mercado_pago_test_account: true
    )
  end

  test "emails the admin and reports to Sentry once per new alert, without personal data" do
    captured = capture_sentry_messages do
      assert_enqueued_emails 1 do
        SellerFraudScanJob.perform_now
      end
      assert_no_enqueued_emails do
        SellerFraudScanJob.perform_now
      end
    end

    message, options = captured.sole
    assert_equal "Alerta de fraude: unverified_account", message
    assert_equal :warning, options[:level]
    assert_equal [ "fraud-alert", "unverified_account", @seller.id.to_s ], options[:fingerprint]
    assert_equal [ :fraud_alert_id, :seller_id ], options[:extra].keys.sort
  end

  test "sends nothing when there are no alerts" do
    @seller.update!(mercado_pago_test_account: false)

    assert_no_enqueued_emails { SellerFraudScanJob.perform_now }
  end

  test "is scheduled in production" do
    raw = ERB.new(Rails.root.join("config/recurring.yml").read).result
    classes = YAML.safe_load(raw, aliases: true).fetch("production").values.filter_map { |c| c["class"] }

    assert_includes classes, "SellerFraudScanJob"
  end

  private

  # Minitest 6 não traz mais `stub`; troca o método só durante o bloco.
  def capture_sentry_messages
    captured = []
    original = Sentry.method(:capture_message)
    Sentry.define_singleton_method(:capture_message) { |message, **options| captured << [ message, options ] }
    yield
    captured
  ensure
    Sentry.define_singleton_method(:capture_message, original)
  end
end
