require "digest"

# Consumidor da API v1 (e da documentação em /api-docs), emitido pelo admin.
# O token só existe em texto puro na memória, logo depois de criado: o banco
# guarda o SHA-256. Um token aleatório de 256 bits não precisa de sal nem de
# hash lento — não há dicionário a atacar —, e o digest determinístico é o que
# permite achar o cliente por índice em vez de comparar um por um.
class ApiClient < ApplicationRecord
  # Gravar `last_used_at` a cada chamada transformaria toda leitura da API em
  # escrita; a precisão de um minuto basta para saber quem ainda usa.
  USAGE_TRACKING_INTERVAL = 1.minute

  attr_reader :token

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }
  validates :token_digest, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  scope :active, -> { where(revoked_at: nil) }

  def self.authenticate(token)
    return if token.blank?

    active.find_by(token_digest: digest(token))
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked?
  end

  def track_usage!(now: Time.current)
    return if last_used_at && last_used_at > now - USAGE_TRACKING_INTERVAL

    update_column(:last_used_at, now)
  end

  private

  def generate_token
    @token = SecureRandom.base58(32)
    self.token_digest = self.class.digest(@token)
  end
end
