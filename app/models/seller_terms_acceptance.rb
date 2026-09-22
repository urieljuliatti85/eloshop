class SellerTermsAcceptance < ApplicationRecord
  belongs_to :user
  belongs_to :seller

  validates :terms_version, :terms_text, :terms_digest, :accepted_at, :ip_address, presence: true
  validates :terms_version, uniqueness: { scope: :user_id }

  def self.current_for?(user)
    exists?(user: user, terms_version: SellerTerms.version)
  end

  def self.record!(user:, seller:, request:)
    find_or_create_by!(user: user, terms_version: SellerTerms.version) do |acceptance|
      acceptance.assign_attributes(
        seller: seller,
        terms_text: SellerTerms.text,
        terms_digest: Digest::SHA256.hexdigest(SellerTerms.text),
        accepted_at: Time.current,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end
  end
end
