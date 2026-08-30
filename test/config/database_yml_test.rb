require "test_helper"
require "erb"
require "yaml"

# Cobre uma armadilha real encontrada na Fase 20 (deploy): `url:` sempre
# vence sobre um `database:` explícito no mesmo hash, então dar aos 4
# papéis (primary/cache/queue/cable) a mesma DATABASE_URL faz db:prepare
# carregar só o schema do primary — os outros três ficam sem tabela
# nenhuma. A config precisa montar host/porta/usuário/senha explícitos a
# partir da URL, com um `database:` diferente por papel. Não testa
# conexão real, só a config resolvida — não precisa de um Postgres de pé.
class DatabaseYmlTest < ActiveSupport::TestCase
  test "production resolves four distinct databases sharing the same connection details from DATABASE_URL" do
    with_database_url("postgres://appuser:secret@db.internal:5432/railway") do
      config = parsed_production_config

      databases = config.values_at("primary", "cache", "queue", "cable").map { |c| c["database"] }
      assert_equal databases.uniq.size, databases.size, "cada papel precisa de um banco físico distinto: #{databases}"

      assert_equal "railway", config["primary"]["database"]
      assert_equal "railway_cache", config["cache"]["database"]
      assert_equal "railway_queue", config["queue"]["database"]
      assert_equal "railway_cable", config["cable"]["database"]

      config.each_value do |role_config|
        assert_equal "db.internal", role_config["host"]
        assert_equal 5432, role_config["port"]
        assert_equal "appuser", role_config["username"]
        assert_equal "secret", role_config["password"]
      end
    end
  end

  private

  def with_database_url(url)
    original = ENV["DATABASE_URL"]
    ENV["DATABASE_URL"] = url
    yield
  ensure
    ENV["DATABASE_URL"] = original
  end

  def parsed_production_config
    template = File.read(Rails.root.join("config/database.yml"))
    YAML.safe_load(ERB.new(template).result, aliases: true, permitted_classes: [ Symbol ])["production"]
  end
end
