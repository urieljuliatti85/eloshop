require "test_helper"

class DistributorInterestTest < ActiveSupport::TestCase
  test "normalizes e-mail and WhatsApp" do
    interest = DistributorInterest.new(email_address: "  ARTESA@EXAMPLE.COM ", whatsapp_number: "+55 (11) 98765-4321", consent_at: Time.current)

    assert_equal "artesa@example.com", interest.email_address
    assert_equal "5511987654321", interest.whatsapp_number
  end

  test "requires a valid Brazilian WhatsApp number with area code" do
    interest = valid_interest(whatsapp_number: "12345")

    assert_not interest.valid?
    assert_includes interest.errors[:whatsapp_number], "deve incluir DDD e número de WhatsApp"
  end

  test "requires consent" do
    interest = valid_interest(consent_at: nil)

    assert_not interest.valid?
    assert_includes interest.errors[:base], "Autorize o contato para continuar."
  end

  test "enforces unique e-mail without case sensitivity" do
    valid_interest(email_address: "Pessoa@Example.com").save!
    duplicate = valid_interest(email_address: "pessoa@example.com")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email_address], "já está em uso"
  end

  test "formats a WhatsApp link number with country code" do
    without_country_code = valid_interest(whatsapp_number: "11987654321")
    with_country_code = valid_interest(whatsapp_number: "5511987654321")

    assert_equal "5511987654321", without_country_code.whatsapp_url_number
    assert_equal "5511987654321", with_country_code.whatsapp_url_number
  end

  private

  def valid_interest(**attributes)
    DistributorInterest.new({
      email_address: "artesa@example.com",
      whatsapp_number: "11987654321",
      consent_at: Time.current
    }.merge(attributes))
  end
end
