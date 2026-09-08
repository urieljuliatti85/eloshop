require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  # Uma tentativa cuja cobrança nunca foi criada permanece `processing` de
  # propósito, para que a próxima tentativa reuse a chave de idempotência.
  # `stalled?` é o que separa "ainda pode chegar" de "não vem mais", e é o que
  # a tela do cliente usa para parar de prometer uma cobrança que falhou.
  test "a processing attempt is not stalled while it is recent" do
    payment = Payment.create!(order: orders(:one), gateway: "mercado_pago", amount_cents: 100,
      status: "processing", idempotency_key: SecureRandom.uuid)

    assert_not payment.stalled?
  end

  test "a processing attempt becomes stalled after the grace period" do
    payment = Payment.create!(order: orders(:one), gateway: "mercado_pago", amount_cents: 100,
      status: "processing", idempotency_key: SecureRandom.uuid,
      created_at: (Payment::PROCESSING_STALE_AFTER + 1.minute).ago)

    assert payment.stalled?
  end

  # Só `processing` fica preso: um pagamento com cobrança criada tem os próprios
  # estados (pending/paid/failed) e nunca deve ser lido como travado.
  test "a pending payment is never stalled, however old" do
    payment = Payment.create!(order: orders(:one), gateway: "mercado_pago", external_id: "mp-1",
      amount_cents: 100, status: "pending", idempotency_key: SecureRandom.uuid,
      created_at: 1.day.ago)

    assert_not payment.stalled?
  end

  test "invalid without gateway" do
    payment = Payment.new(order: orders(:one), external_id: "x", amount_cents: 100)
    assert_not payment.valid?
    assert_includes payment.errors[:gateway], "can't be blank"
  end

  test "invalid without external_id" do
    payment = Payment.new(order: orders(:one), gateway: "fake", amount_cents: 100)
    assert_not payment.valid?
    assert_includes payment.errors[:external_id], "can't be blank"
  end

  test "invalid with negative amount_cents" do
    payment = Payment.new(order: orders(:one), gateway: "fake", external_id: "x", amount_cents: -1)
    assert_not payment.valid?
    assert_includes payment.errors[:amount_cents], "must be greater than or equal to 0"
  end

  test "defaults to pending status" do
    payment = Payment.create!(order: orders(:one), gateway: "fake", external_id: SecureRandom.hex(10), amount_cents: 100)
    assert payment.pending?
  end

  test "generates a unique idempotency key" do
    payment = Payment.create!(order: orders(:one), gateway: "fake", external_id: SecureRandom.hex(10), amount_cents: 100)

    assert payment.idempotency_key.present?
    assert_not_equal payments(:one).idempotency_key, payment.idempotency_key
  end

  test "only considers a payment expired after its expiration time" do
    payment = payments(:one)

    payment.expires_at = 1.second.ago
    assert payment.expired?

    payment.expires_at = 1.second.from_now
    assert_not payment.expired?

    payment.expires_at = nil
    assert_not payment.expired?
  end
end
