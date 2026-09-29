require "test_helper"

# Delivery method que sempre falha, para exercitar a política de repetição sem
# tocar na rede.
class FailingDelivery
  cattr_accessor :error

  def initialize(_settings); end

  def deliver!(_mail)
    raise self.class.error
  end
end
ActionMailer::Base.add_delivery_method :failing_for_test, FailingDelivery

class EmailDeliveryRetryTest < ActiveJob::TestCase
  setup { WelcomeMailer.delivery_method = :failing_for_test }
  teardown { WelcomeMailer.delivery_method = :test }

  test "job de aviso repete quando o Resend devolve 500" do
    FailingDelivery.error = Resend::Error::InternalServerError.new("boom", 500)

    assert_nothing_raised { SendWelcomeCustomerJob.perform_now(customers(:one)) }
    assert_enqueued_jobs 1, only: SendWelcomeCustomerJob
  end

  test "job de aviso repete quando a conexão com o Resend não abre" do
    FailingDelivery.error = Net::OpenTimeout.new

    assert_nothing_raised { SendWelcomeCustomerJob.perform_now(customers(:one)) }
    assert_enqueued_jobs 1, only: SendWelcomeCustomerJob
  end

  test "job de aviso repete no limite de taxa (429)" do
    FailingDelivery.error = Resend::Error::RateLimitExceededError.new("slow down", 429, {})

    assert_nothing_raised { SendWelcomeCustomerJob.perform_now(customers(:one)) }
    assert_enqueued_jobs 1, only: SendWelcomeCustomerJob
  end

  test "chave inválida não é repetida e a falha aparece" do
    FailingDelivery.error = Resend::Error::InvalidRequestError.new("API key is invalid", 401)

    assert_raises(Resend::Error::InvalidRequestError) do
      SendWelcomeCustomerJob.perform_now(customers(:one))
    end
    assert_enqueued_jobs 0
  end

  test "read timeout não é repetido, porque o envio pode ter sido aceito" do
    FailingDelivery.error = Net::ReadTimeout.new

    assert_raises(Net::ReadTimeout) { SendWelcomeCustomerJob.perform_now(customers(:one)) }
    assert_enqueued_jobs 0
  end

  test "deliver_later usa o job com repetição e repete falha transitória" do
    assert_equal ApplicationMailDeliveryJob, ApplicationMailer.delivery_job
    FailingDelivery.error = Resend::Error::InternalServerError.new("boom", 500)

    assert_nothing_raised do
      ApplicationMailDeliveryJob.perform_now(
        "WelcomeMailer", "welcome_customer", "deliver_now", args: [ customers(:one) ]
      )
    end
    assert_enqueued_jobs 1, only: ApplicationMailDeliveryJob
  end

  test "deliver_later com chave inválida falha de vez" do
    FailingDelivery.error = Resend::Error::InvalidRequestError.new("API key is invalid", 401)

    assert_raises(Resend::Error::InvalidRequestError) do
      ApplicationMailDeliveryJob.perform_now(
        "WelcomeMailer", "welcome_customer", "deliver_now", args: [ customers(:one) ]
      )
    end
    assert_enqueued_jobs 0
  end
end
