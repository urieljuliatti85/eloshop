# EloShop

E-commerce e Marketplace dedicado ao público que fabrica artesanato e produtos feitos à mão.

## Stack

* Ruby 3.3.11 / Rails 8.1
* PostgreSQL 16
* Hotwire (Turbo + Stimulus)
* Tailwind CSS
* Active Storage
* Solid Queue, Solid Cache, Solid Cable
* RSpec + rswag (suíte principal de testes e documentação de API)
* Capybara + Selenium para testes de sistema

## Requisitos

* Ruby `3.3.11` (veja `.ruby-version`)
* Docker (para subir o PostgreSQL local)

## Configuração inicial

```bash
bin/setup
```

Instala as dependências, prepara o banco de dados, limpa logs/tmp, instala o
git hook de pre-commit (RuboCop + testes, ver `.githooks/README.md`) e sobe
`bin/dev`. Para pular a subida do servidor: `bin/setup --skip-server`.

Alternativa manual, passo a passo:

```bash
bundle install
docker compose up -d      # sobe o Postgres em localhost:5432
cp .env.example .env      # opcional, defaults já batem com o docker-compose
bin/rails db:setup        # cria os bancos e carrega o schema
```

O `docker-compose.yml` cria o banco `eloshop_development` com usuário/senha
`eloshop`/`eloshop`. As credenciais podem ser sobrescritas via variáveis de
ambiente (`DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USERNAME`,
`DATABASE_PASSWORD`) — veja `config/database.yml`.

## Rodando o servidor

```bash
bin/dev
```

Sobe o servidor Rails e o watcher do Tailwind (via `Procfile.dev`) em
`http://localhost:3000`. A área administrativa fica em `/admin` (autenticação
própria, ver `app/controllers/admin/`).

## Testes

```bash
bundle exec rspec                     # suíte principal de testes
bundle exec rspec spec/requests       # request specs e OpenAPI
bin/rails rswag:specs:swaggerize     # gera swagger/v1/swagger.yaml
bin/rails test:system                 # testes de sistema (Capybara + Selenium)
```

## Documentação de API

Com o servidor rodando, a UI do Swagger fica em `/api-docs`. O arquivo
`swagger/v1/swagger.yaml` é gerado a partir dos specs em `spec/requests/`:

```bash
bin/rails rswag:specs:swaggerize
```

## Lint e segurança

```bash
bin/rubocop         # lint
bin/brakeman        # análise estática de segurança
bin/bundler-audit   # vulnerabilidades conhecidas em gems
```

CI (GitHub Actions, `.github/workflows/`) roda lint, testes, testes de
sistema, Brakeman/bundler-audit e CodeQL a cada push/PR em `main`.

## Documentação do domínio

O contexto de negócio e as decisões arquiteturais estão em `docs/`. Consulte
`ROADMAP.md` para o estado atual do projeto e a próxima fase planejada.
