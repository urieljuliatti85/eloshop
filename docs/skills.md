# Skills de revisão e QA do Claude Code

Este projeto tem três skills do Claude Code para revisar e testar o que
é construído. Elas vivem em `.claude/skills/` e são carregadas em toda
sessão do Claude Code aberta neste repositório.

| Skill | Pergunta que responde | Altera arquivos? |
|---|---|---|
| `principal-reviewer` | O sistema ou o desenho aguenta carga, falhas, ataques e evolução? | Não |
| `qa` | Funciona de verdade, inclusive quando algo dá errado? | Só testes, salvo pedido de correção |
| `pr-reviewer` | Este diff introduz bug, regressão ou risco? | Não |

## Regra principal: só rodam quando você chama

As três têm `disable-model-invocation: true` no `SKILL.md`. Isso quer dizer:

- O Claude Code **não** as aciona sozinho a partir de um pedido em texto
  ("revisa esse PR" não basta). Só rodam com o comando explícito
  (`/pr-reviewer`, `/principal-reviewer`, `/qa`).
- **Não existe automação em CI, hook ou rotina agendada** para elas, de
  propósito. Não crie uma sem rever os riscos da seção
  "Por que não automatizar".

Nunca remova `disable-model-invocation` sem uma decisão explícita.

## Como chamar

```text
/pr-reviewer 274                 # revisa o PR 274
/pr-reviewer                     # sem argumento: diff da branch atual contra a main
/principal-reviewer fluxo de checkout → pagamento → webhook
/principal-reviewer integração de frete antes de implementar
/qa                              # sem argumento: valida as alterações da branch atual
/qa jornada de compra por PIX
/qa segurança do painel do vendedor
```

O argumento é o escopo. Quanto mais preciso, mais focada a revisão:
diga o fluxo, o PR, o módulo ou o risco que preocupa.

## Quando usar cada uma

Fluxo sugerido de uma feature:

1. **Antes de implementar algo grande** (toca dinheiro, integração,
   infraestrutura, autorização ou muda o desenho): `/principal-reviewer`
   sobre o plano ou o fluxo afetado.
2. **Implementação.**
3. **Terminou:** `/qa` na branch, para validar e completar os testes.
4. **Antes do merge:** `/pr-reviewer`, já com os testes da etapa 3.

Atalhos:

- Mudança pequena (texto, ajuste visual, cópia): só `/pr-reviewer`.
- Bug em produção: `/qa` para reproduzir e escrever o teste de
  regressão antes da correção.
- Fim de uma fase do ROADMAP ou dúvida de escala/segurança:
  `/principal-reviewer` sobre o fluxo inteiro.

## Boas práticas por skill

### `pr-reviewer`

- Rode no diff final, depois do `/qa`, para revisar também os testes.
- Leia os achados como hipóteses fundamentadas: cada um traz arquivo,
  linhas, cenário e impacto. Confira o cenário antes de corrigir.
- Ela não comenta no GitHub, não aprova e não faz merge. Se quiser o
  resultado no PR, peça explicitamente depois de ler.
- Não substitui a sua leitura do diff, principalmente em pagamento,
  comissão e autorização.

### `principal-reviewer`

- Use antes de codar, quando mudar o desenho ainda é barato.
- Dê o escopo como um fluxo ou uma fronteira, não um arquivo.
- As decisões que ela devolve no formato "Opção A / Opção B /
  Recomendação" são suas: comissão, frete e políticas são decisões de
  negócio (CLAUDE.md, §69).
- Recomendações vêm com "quando agir". "Ainda não" é uma resposta
  válida; registre no ROADMAP o que ficou para depois.

### `qa`

- Sem argumento, valida a branch atual. Para fluxos ou riscos
  específicos, diga quais.
- Escreve testes de regressão na suíte certa: domínio e serviços em
  Minitest, endpoints e autorização em RSpec. Revise os testes que ela
  criar antes de commitar.
- Não corrige código de produção a menos que você peça
  ("valida e corrige").
- Testes de carga, força bruta e concorrência pesada rodam só local ou
  em ambiente isolado, **nunca em produção**. Pagamento, só em sandbox.
- Ela não instala ferramentas novas sem pedir.

## Depois do relatório

Cada skill entrega um relatório com achados por gravidade
(CRITICAL, HIGH, MEDIUM, LOW). A partir dele, você decide:

- "corrige os achados HIGH" → correção num commit próprio, com teste;
- "abre uma issue para o MEDIUM";
- "ignora o 3, é decisão de negócio".

Ausência de achados não é garantia de ausência de bugs: o relatório
lista o que foi coberto e o que ficou de fora.

## Por que não automatizar

Decisão de 2026-10-27: as três rodam só manualmente. Os riscos de
automatizar:

- **Instruções escondidas no PR (prompt injection):** o revisor lê diff,
  descrição e comentários. Uma automação com permissão de aprovar,
  fazer merge ou push poderia ser induzida a isso.
- **Credenciais:** em CI, a skill teria acesso ao que o ambiente expõe.
  Segredos de produção (banco, Mercado Pago, Railway) nunca podem estar lá.
- **Trava de deploy:** o deploy depende do "Wait for CI" da Railway. Um
  revisor de IA como check obrigatório trava a produção num falso positivo.
- **`qa` executa e escreve:** rodando sozinha, poderia fazer testes de
  segurança ou de carga contra o ambiente errado ou commitar testes
  sem revisão.
- **Ruído e custo:** revisão a cada push gera comentários repetidos e
  gasto de tokens, e a equipe passa a ignorá-los.

Se um dia a automação for desejada, o mínimo aceitável é: só a
`pr-reviewer`, com permissão apenas de comentar, sem segredos de
produção, nunca como check obrigatório e nunca aprovando ou fazendo merge.

## Manutenção

- Cada skill é um `SKILL.md` em `.claude/skills/<nome>/`. Mude por PR,
  como qualquer código.
- A seção "Pontos de atenção deste projeto" / "Particularidades deste
  projeto" das skills resume fatos que mudam (infra, provedores). Quando
  o CLAUDE.md ou os docs mudarem nesses pontos, atualize as skills junto.
