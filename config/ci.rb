# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Tests: RSpec", "bundle exec rspec"
  # Minitest cobre models, services e integração — camadas por onde o RSpec
  # não passa. Sem os testes de sistema, que têm job próprio no GitHub.
  step "Tests: Minitest", "bin/rails test"
  step "API docs: Swagger", "bin/rails rswag:specs:swaggerize"
  # `db:seed:replant` trocado por prepare + seed: replant limpa com TRUNCATE,
  # que pega ACCESS EXCLUSIVE e entra em deadlock contra qualquer conexão
  # remanescente no banco de teste — a mesma razão que levou os specs a
  # trocarem TRUNCATE por DELETE (ver spec/support/authentication_helpers.rb).
  # Observado aqui em 2 de 3 execuções seguidas, como deadlock e como violação
  # de FK sobre linha de fixture sobrevivente.
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:test:prepare db:seed"
  # Invocação separada de propósito: o Rake não roda a mesma task duas vezes
  # dentro de uma invocação. Devolve o banco vazio para a próxima rodada da
  # suíte não encontrar o catálogo de exemplo.
  step "Tests: Reset do banco de teste", "env RAILS_ENV=test bin/rails db:test:prepare"

  # Optional: Run system tests
  # step "Tests: System", "bin/rails test:system"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
