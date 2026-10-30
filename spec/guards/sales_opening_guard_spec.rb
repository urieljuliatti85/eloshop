# frozen_string_literal: true

require "rails_helper"

# A abertura das vendas é um ato do admin, uma vez, pelo dashboard: a data
# marca o início da comissão de lançamento de quem já estava aprovado e
# dispara o aviso a todos os vendedores. Nada que sobe com o código — migration,
# seed, entrypoint, task, job, initializer — pode abrir as vendas sozinho num
# deploy. Este guarda varre o código que vai para produção e falha se surgir
# outro caminho até `sales_opened_at`. Fica no RSpec de propósito: é a suíte do
# pre-commit, então o bloqueio vale já no commit, além do CI que segura o deploy.
#
# Testes estão fora da varredura: as suítes abrem as vendas no banco de teste
# (`spec/rails_helper.rb`, fixture do Minitest), que nunca sobe.
RSpec.describe "Guarda da abertura das vendas" do
  SCANNED_PATHS = %w[app lib db config bin script].freeze
  SCANNED_EXTENSIONS = %w[.rb .rake .erb .yml .sql].freeze
  SCANNED_SCRIPTS = %w[bin/docker-entrypoint Dockerfile].freeze

  OPEN_SALES_CALLERS = %w[
    app/controllers/admin/sales_openings_controller.rb
    app/models/platform_setting.rb
  ].freeze

  # Onde `sales_opened_at` pode ser escrito: o próprio `open_sales!` e a
  # migration que cria a coluna (nula, isto é, vendas fechadas).
  SALES_OPENED_AT_WRITERS = %w[
    app/models/platform_setting.rb
    db/migrate/20261028120000_create_platform_settings.rb
  ].freeze

  # Toda forma de escrever na coluna: hash (`update!(sales_opened_at: ...)`),
  # símbolo (`update_column(:sales_opened_at, ...)`, `[:sales_opened_at] =`),
  # setter (`setting.sales_opened_at = ...`), nome em string e SQL cru.
  # Leitura (`PlatformSetting.sales_opened_at`, variável local) não casa.
  WRITE_PATTERNS = [
    /\bsales_opened_at:/,
    /:sales_opened_at\b/,
    /\.sales_opened_at\s*=(?!=)/,
    /["'`]sales_opened_at\b/,
    /\bSET\b.*\bsales_opened_at\b/i
  ].freeze

  def shipped_files
    files = SCANNED_PATHS.flat_map { |dir| Dir.glob(Rails.root.join(dir, "**", "*")) }
      .select { |path| File.file?(path) && SCANNED_EXTENSIONS.include?(File.extname(path)) }
    files += SCANNED_SCRIPTS.map { |path| Rails.root.join(path).to_s }.select { |path| File.file?(path) }
    files.map { |path| Pathname(path).relative_path_from(Rails.root).to_s } - [ "db/schema.rb" ]
  end

  def offenders(pattern_list, allowed)
    (shipped_files - allowed).flat_map do |path|
      File.readlines(Rails.root.join(path)).each_with_index.filter_map do |line, index|
        next if line.lstrip.start_with?("#") # comentário não executa nada

        "#{path}:#{index + 1}: #{line.strip}" if pattern_list.any? { |pattern| line.match?(pattern) }
      end
    end
  end

  it "só o controller do dashboard do admin chama open_sales!" do
    expect(offenders([ /\bopen_sales!/ ], OPEN_SALES_CALLERS)).to be_empty
  end

  it "só o PlatformSetting escreve sales_opened_at" do
    expect(offenders(WRITE_PATTERNS, SALES_OPENED_AT_WRITERS)).to be_empty
  end

  it "o seed de produção e o de desenvolvimento não tocam na abertura" do
    seeds = shipped_files.grep(%r{\Adb/seeds})

    expect(seeds).not_to be_empty
    # Mais estrito que os demais: nos seeds nem a leitura tem motivo de estar.
    only_seeds = shipped_files - seeds
    expect(offenders([ /\bopen_sales!/, /\bsales_opened_at\b/ ], only_seeds)).to be_empty
  end

  # Se a varredura parasse de reconhecer as formas de escrita, os exemplos
  # acima passariam sem proteger nada.
  it "reconhece as formas de escrita e ignora as leituras" do
    writes = [
      "PlatformSetting.instance.update!(sales_opened_at: Time.current)",
      "setting.update_column(:sales_opened_at, Time.current)",
      "setting.sales_opened_at = Time.current",
      "setting[:sales_opened_at] = Time.current",
      %(PlatformSetting.update_all("sales_opened_at = now()")),
      %(execute "UPDATE platform_settings SET sales_opened_at = now()")
    ]
    reads = [
      "sales_opened_at = PlatformSetting.sales_opened_at",
      "PlatformSetting.sales_opened_at.present?",
      "return false if setting.sales_opened_at.present?",
      "setting.sales_opened_at == other"
    ]

    writes.each { |line| expect(WRITE_PATTERNS.any? { |p| line.match?(p) }).to be(true), line }
    reads.each { |line| expect(WRITE_PATTERNS.none? { |p| line.match?(p) }).to be(true), line }
  end
end
