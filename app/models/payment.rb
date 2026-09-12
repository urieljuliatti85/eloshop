class Payment < ApplicationRecord
  before_validation :ensure_idempotency_key, on: :create

  belongs_to :order
  has_many :payment_events, dependent: :destroy
  has_many :payment_refunds, dependent: :destroy

  enum :status, {
    processing: "processing",
    pending: "pending",
    authorized: "authorized",
    paid: "paid",
    partially_refunded: "partially_refunded",
    refunded: "refunded",
    failed: "failed"
  }, default: "pending"

  enum :payment_method, {
    pix: "pix",
    credit_card: "credit_card"
  }, default: "pix"

  # Uma tentativa `processing` que passou disso não vai mais virar cobrança: a
  # criação no gateway falhou. O registro continua `processing` de propósito
  # (`Payments::Authorize` reusa a chave de idempotência, porque a cobrança pode
  # ter nascido do outro lado), mas a tela do cliente para de prometer que ela
  # está a caminho. O limite é generoso perto dos timeouts do gateway
  # (5s de conexão, 15s de leitura) para não acusar falha numa cobrança lenta.
  PROCESSING_STALE_AFTER = 2.minutes

  validates :gateway, presence: true
  validates :external_id, presence: true, unless: :processing?
  validates :idempotency_key, presence: true, uniqueness: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :application_fee_cents, :refunded_amount_cents, :application_fee_refunded_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :processor_fee_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :installments, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validate :financial_accounting_is_bounded

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  # A criação da cobrança falhou e não vai se resolver sozinha — o cliente
  # precisa tentar de novo. Ver PROCESSING_STALE_AFTER.
  def stalled?
    processing? && created_at.present? && created_at <= PROCESSING_STALE_AFTER.ago
  end

  # Estados em que oferecer "tentar de novo" é correto: a cobrança falhou, ou
  # expirou, ou nunca chegou a ser criada. Fonte única para a view (que decide
  # se mostra o caminho de volta) e para o controller (que decide se aceita
  # voltar à escolha do meio) — as duas perguntas são a mesma, e separá-las
  # deixaria a tela oferecendo um link que a ação recusa.
  #
  # `authorized`/`paid` ficam de fora de propósito: ali há cobrança válida, e
  # refazer arriscaria cobrar duas vezes.
  def retryable?
    failed? || stalled? || (pending? && expired?)
  end

  def remaining_refundable_cents
    amount_cents - refunded_amount_cents
  end

  private

  def ensure_idempotency_key
    self.idempotency_key ||= SecureRandom.uuid
  end

  def financial_accounting_is_bounded
    errors.add(:application_fee_cents, "não pode superar o pagamento") if application_fee_cents.to_i > amount_cents.to_i
    errors.add(:refunded_amount_cents, "não pode superar o pagamento") if refunded_amount_cents.to_i > amount_cents.to_i
    if application_fee_refunded_cents.to_i > application_fee_cents.to_i
      errors.add(:application_fee_refunded_cents, "não pode superar a comissão")
    end
  end
end
