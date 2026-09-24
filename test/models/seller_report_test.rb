require "test_helper"

class SellerReportTest < ActiveSupport::TestCase
  test "invalid without a reason" do
    report = SellerReport.new(customer: customers(:one), seller: sellers(:approved))
    assert_not report.valid?
    assert_includes report.errors[:reason], "can't be blank"
  end

  test "invalid with a reason outside the allowed list" do
    report = SellerReport.new(customer: customers(:one), seller: sellers(:approved), reason: "not-a-real-reason")
    assert_not report.valid?
    assert_includes report.errors[:reason], "is not included in the list"
  end

  test "invalid when the same customer reports the same seller twice" do
    customers(:one).seller_reports.create!(seller: sellers(:approved), reason: "fraud")

    duplicate = SellerReport.new(customer: customers(:one), seller: sellers(:approved), reason: "counterfeit")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:customer_id], "você já denunciou este ateliê"
  end

  test "defaults to pending status" do
    report = customers(:one).seller_reports.create!(seller: sellers(:approved), reason: "fraud")
    assert report.pending?
  end

  test "review!, resolve! and dismiss! transition status" do
    report = customers(:one).seller_reports.create!(seller: sellers(:approved), reason: "fraud")

    report.review!
    assert report.reviewing?

    report.resolve!
    assert report.resolved?

    report2 = customers(:two).seller_reports.create!(seller: sellers(:approved), reason: "counterfeit")
    report2.dismiss!
    assert report2.dismissed?
  end

  test "reason_label returns the human readable reason" do
    report = customers(:one).seller_reports.create!(seller: sellers(:approved), reason: "fraud")
    assert_equal "Atividade fraudulenta", report.reason_label
  end
end
