# Cadastro manual das contas TESTUSER do sandbox do Mercado Pago (Comprador,
# Vendedor, Marketplace). Esses dados não existem na API do Mercado Pago de
# forma consultável pelo nosso código — o painel deles só mostra ao humano —
# então um admin cadastra aqui à mão para não precisar reabrir o painel do
# Mercado Pago toda vez que for testar o sandbox.
#
# Apesar de serem credenciais de teste (nunca movimentam dinheiro real), a
# senha ainda é cifrada em repouso, seguindo o mesmo padrão de
# Seller#credential_encryptor — nunca gravar segredo em texto puro, mesmo
# quando o risco de vazamento é baixo (CLAUDE.md §43).
class MercadoPagoTestAccount < ApplicationRecord
  enum :account_type, {
    buyer: "buyer",
    seller: "seller",
    marketplace: "marketplace"
  }

  validates :account_type, presence: true
  validates :label, presence: true

  def password=(plain_password)
    self.password_ciphertext = plain_password.present? ? credential_encryptor.encrypt_and_sign(plain_password) : nil
  end

  def password
    credential_encryptor.decrypt_and_verify(password_ciphertext) if password_ciphertext.present?
  end

  private

  CREDENTIAL_ENCRYPTION_SALT = "mercado-pago-test-account-password".freeze

  def credential_encryptor
    key = Rails.application.key_generator.generate_key(
      CREDENTIAL_ENCRYPTION_SALT,
      ActiveSupport::MessageEncryptor.key_len
    )
    ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
  end
end
