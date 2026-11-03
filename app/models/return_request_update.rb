# Histórico de uma solicitação pós-venda: abertura pelo comprador, respostas e
# mudanças de status pelo admin. Só cresce — não há edição nem exclusão.
class ReturnRequestUpdate < ApplicationRecord
  belongs_to :return_request
  belongs_to :author, polymorphic: true

  validates :author_type, inclusion: { in: %w[Customer User] }
  validates :body, length: { maximum: 2000 }
  validate :has_content

  scope :chronological, -> { order(:created_at, :id) }

  def status_change?
    to_status.present?
  end

  private

  def has_content
    errors.add(:body, "não pode ficar em branco") if body.blank? && to_status.blank?
  end
end
