# EloShop

E-commerce de artesanato e produtos feitos à mão, construído em Ruby on Rails.

## Stack

* Ruby 3.3.11 / Rails 8.1
* PostgreSQL 16
* Hotwire (Turbo + Stimulus)
* Tailwind CSS
* Solid Queue, Solid Cache, Solid Cable
* Minitest + Capybara

## Requisitos

* Ruby `3.3.11` (veja `.ruby-version`)
* Docker (para subir o PostgreSQL local)

## Configuração inicial

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
`http://localhost:3000`.

## Testes

```bash
bin/rails test
```

## Lint

```bash
bin/rubocop
```

## Documentação do domínio

O contexto de negócio e as decisões arquiteturais estão em `docs/`. Consulte
`ROADMAP.md` para o estado atual do projeto e a próxima fase planejada.
