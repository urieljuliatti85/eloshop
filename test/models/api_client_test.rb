require "test_helper"

class ApiClientTest < ActiveSupport::TestCase
  test "gera o token na criação e guarda só o digest" do
    client = ApiClient.create!(name: "Parceiro")

    assert client.token.present?
    assert_equal ApiClient.digest(client.token), client.token_digest
    assert_not_includes ApiClient.find(client.id).attributes.values, client.token
  end

  test "o token começa com o prefixo da EloShop" do
    client = ApiClient.create!(name: "Parceiro")

    assert client.token.start_with?(ApiClient::TOKEN_PREFIX)
    assert_operator client.token.delete_prefix(ApiClient::TOKEN_PREFIX).length, :>=, 32
  end

  test "token emitido antes do prefixo continua autenticando" do
    legacy_token = SecureRandom.base58(32)
    client = ApiClient.create!(name: "Parceiro antigo")
    client.update_column(:token_digest, ApiClient.digest(legacy_token))

    assert_equal client, ApiClient.authenticate(legacy_token)
  end

  test "o token não volta depois de recarregar" do
    client = ApiClient.create!(name: "Parceiro")

    assert_nil ApiClient.find(client.id).token
  end

  test "tokens diferentes para clientes diferentes" do
    assert_not_equal ApiClient.create!(name: "A").token, ApiClient.create!(name: "B").token
  end

  test "exige nome único sem diferenciar maiúsculas" do
    ApiClient.create!(name: "Parceiro")
    client = ApiClient.new(name: "PARCEIRO")

    assert_not client.valid?
    assert client.errors[:name].any?
  end

  test "authenticate acha o cliente ativo pelo token" do
    client = ApiClient.create!(name: "Parceiro")

    assert_equal client, ApiClient.authenticate(client.token)
  end

  test "authenticate recusa token vazio, desconhecido ou revogado" do
    client = ApiClient.create!(name: "Parceiro")
    client.revoke!

    assert_nil ApiClient.authenticate(nil)
    assert_nil ApiClient.authenticate("")
    assert_nil ApiClient.authenticate("desconhecido")
    assert_nil ApiClient.authenticate(client.token)
  end

  test "revogar duas vezes mantém a primeira data" do
    client = ApiClient.create!(name: "Parceiro")
    client.revoke!
    first = client.revoked_at

    travel 1.day do
      client.revoke!
    end

    assert_equal first, client.reload.revoked_at
  end

  test "track_usage! grava no máximo uma vez por intervalo" do
    client = ApiClient.create!(name: "Parceiro")
    now = Time.current.change(usec: 0)

    client.track_usage!(now: now)
    client.track_usage!(now: now + 30.seconds)
    assert_equal now, client.reload.last_used_at

    client.track_usage!(now: now + 2.minutes)
    assert_equal now + 2.minutes, client.reload.last_used_at
  end
end
