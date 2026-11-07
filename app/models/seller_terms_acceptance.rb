class SellerTermsAcceptance < ApplicationRecord
  belongs_to :user
  belongs_to :seller

  validates :terms_version, :terms_text, :terms_digest, :accepted_at, :ip_address, presence: true
  validates :terms_version, uniqueness: { scope: :user_id }

  # A versão vigente é a do tipo do vendedor (ADR 007): ateliê e distribuidor
  # têm termos próprios. Usuário sem vendedor não tem termos a aceitar.
  def self.current_for?(user)
    seller = user&.seller
    return false if seller.blank?

    exists?(user: user, terms_version: SellerTerms.version(seller.kind))
  end

  def self.record!(user:, seller:, request:)
    version = SellerTerms.version(seller.kind)
    text = SellerTerms.text(seller.kind)

    find_or_create_by!(user: user, terms_version: version) do |acceptance|
      acceptance.assign_attributes(
        seller: seller,
        terms_text: text,
        terms_digest: Digest::SHA256.hexdigest(text),
        accepted_at: Time.current,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end
  end
end
