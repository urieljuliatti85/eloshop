# Git hooks

`.git/hooks/` não é versionado pelo Git, então os hooks ficam aqui em
`.githooks/` e são instalados (copiados) para `.git/hooks/` por `bin/setup`.

Depois de clonar o repositório, rode `bin/setup` para instalar o hook
`pre-commit`, que roda `bin/rubocop` e `bin/rails test` antes de cada
commit — o commit é abortado se algum dos dois falhar.

Para reinstalar manualmente (ex.: depois de editar `.githooks/pre-commit`):

```bash
cp .githooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Para pular o hook pontualmente: `git commit --no-verify` (evite usar
sem necessidade — ver CLAUDE.md).
