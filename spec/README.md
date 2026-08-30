# spec/

Este diretório existe só para os specs do **rswag** (documentação e teste de
API via OpenAPI/Swagger). A suíte de testes principal do projeto continua em
Minitest, em `test/` — ver `ROADMAP.md` e `CLAUDE.md`.

Quando um endpoint JSON for adicionado (`app/controllers/api/...`), o spec
correspondente vai em `spec/requests/`, seguindo a DSL do rswag
(`path`, `get`, `response`, `schema`). Rodar com `bundle exec rspec`.

Para regenerar `swagger/v1/swagger.yaml` a partir dos specs:

```bash
bin/rails rswag:specs:swaggerize
```

A UI do Swagger fica disponível em `/api-docs` com o servidor rodando.
