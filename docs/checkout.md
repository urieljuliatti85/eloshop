# Checkout

Este documento descreve o fluxo de checkout. Para as entidades envolvidas, ver `docs/domain.md`. Para estoque e pagamento, ver `docs/inventory.md` e `docs/payments.md`.

## Fluxo (visão de domínio completa)

```text
Carrinho
    ↓
Identificação
    ↓
Endereço
    ↓
Frete
    ↓
Personalizações
    ↓
Cupons
    ↓
Resumo
    ↓
Pagamento
    ↓
Pedido
    ↓
Confirmação
```

## Escopo do MVP

No MVP (Fase 5 do `ROADMAP.md`), o fluxo é reduzido às etapas essenciais:

```text
Carrinho → Identificação/Endereço → Frete (valor fixo) → Resumo → Pagamento → Pedido
```

As etapas "Personalizações" e "Cupons" não existem ainda — são adicionadas nas Fases 10 e 13, respectivamente, quando os domínios correspondentes forem implementados.

## Princípio central: nunca confiar no cliente

O servidor deve sempre recalcular, no momento do checkout, independentemente do que foi enviado pelo navegador:

* preço de cada item
* desconto (quando existir)
* frete
* subtotal e total
* disponibilidade de cada item

Um preço ou total vindos do client nunca devem ser usados diretamente para criar o pedido.

## Carrinho não é reserva de estoque

Um item presente no carrinho pode se tornar indisponível antes do checkout ser concluído (outro cliente comprou a última unidade, produto foi descontinuado, etc.). O checkout deve validar a disponibilidade novamente no momento da finalização, não confiar na validação feita quando o item foi adicionado ao carrinho.

## Snapshot no pedido

Ao criar o `Order`/`OrderItem`, o checkout deve gravar um snapshot de:

* nome do produto, SKU e preço unitário no momento da compra
* endereço de entrega utilizado

Pedidos já criados nunca devem depender dos dados atuais do produto, do cliente ou do endereço (ver `docs/domain.md`, seção `Order`).

## Idempotência

O checkout é uma operação que pode ser repetida (duplo clique, timeout seguido de retry, reenvio de formulário) e deve ser idempotente: a mesma tentativa de checkout não pode gerar dois pedidos.

`TODO — DECISION REQUIRED`: o mecanismo exato de idempotência (ex.: chave de idempotência gerada no client vs. gerada no servidor a partir do carrinho, tempo de expiração da chave) não está definido — deve ser decidido durante a implementação da Fase 5, com base na necessidade concreta observada.

## Concorrência

O caso mais crítico do domínio de artesanato é a venda de peça única (estoque = 1) para dois clientes em checkout simultâneo. O checkout deve garantir, via transação e locking (ver `docs/inventory.md`), que apenas um dos dois consiga concluir a compra.

## Edge cases a considerar (quando aplicável à fase em implementação)

```text
Produto removido
Produto descontinuado
Estoque zerado
Última unidade
Compra simultânea
Preço alterado
Variante indisponível (pós-MVP)
Personalização inválida (pós-MVP)
Cupom expirado (pós-MVP)
Frete indisponível (pós-MVP — frete real)
Pagamento recusado
Pagamento duplicado
Webhook duplicado
Timeout
Retry
```
