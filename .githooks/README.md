# Git hooks

`.git/hooks/` não é versionado pelo Git, então os hooks ficam aqui em
`.githooks/` e são instalados (copiados) para `.git/hooks/` por `bin/setup`.

Depois de clonar o repositório, rode `bin/setup` para instalar o hook
`pre-commit`, que roda `bin/check-sensitive-terms`, `bin/rubocop` e
`bundle exec rspec` antes de cada commit — o commit é abortado se algum
deles falhar.

`bin/check-sensitive-terms` procura, nas linhas acrescentadas, os termos de
uma lista privada em `.git/info/sensitive-terms` (um termo ou expressão
regular por linha). A lista fica dentro de `.git`, fora do versionamento,
porque o repositório é público; sem ela, a checagem é pulada. Só
bloqueia ocorrência nova: editar uma linha que já tinha o termo não bloqueia.

Para reinstalar manualmente (ex.: depois de editar `.githooks/pre-commit`):

```bash
cp .githooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Para pular o hook pontualmente: `git commit --no-verify` (evite usar
sem necessidade — ver CLAUDE.md).
