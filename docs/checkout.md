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

A etapa "Cupons" (Fase 13) não é uma página própria do checkout: o cupom é aplicado no carrinho (`POST /cart/apply_coupon`) e revalidado no momento da finalização, junto com estoque e frete — ver `Coupon` em `docs/domain.md`. "Personalizações" (Fase 10) segue o mesmo padrão: a escolha acontece antes, na página do produto/ao adicionar ao carrinho (ver `PersonalizationOption` em `docs/domain.md`) — o resumo do pedido só exibe o que já foi escolhido, não pede pra preencher de novo.

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

**Decisão (Fase 5)**: chave gerada no servidor (`SecureRandom.hex`) e guardada na sessão HTTP quando o cliente entra na tela de revisão do pedido (`OrdersController#new`); usada na criação do pedido e removida da sessão após sucesso. `orders.idempotency_key` tem índice único no banco — uma tentativa duplicada (inclusive sob concorrência real, via `ActiveRecord::RecordNotUnique`) retorna o pedido já criado em vez de duplicar. Ver `Checkout::CreateOrder`.

## Marketplace

Desde a Fase 22, o carrinho aceita produtos de um único vendedor. A validação acontece ao adicionar o item e novamente dentro da transação de `Checkout::CreateOrder`, cobrindo carrinhos legados e concorrência. Isso preserva o lançamento com split 1:1 do Mercado Pago.

O `Order` principal agrega `SellerOrder`s para dividir frete/fulfillment, status, cancelamento e repasse por artesão. O primeiro lançamento cria exatamente um `SellerOrder`, no mesmo lock/transação que cria o pedido e baixa o estoque. Checkout multi-vendedor depende de acesso comercial ao split 1:N; não são usados múltiplos PIX nem repasse manual pela plataforma.

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
Variante indisponível (Fase 9)
Personalização inválida (Fase 10)
Cupom expirado (pós-MVP)
Frete indisponível (pós-MVP — frete real)
Pagamento recusado
Pagamento duplicado
Webhook duplicado
Timeout
Retry
```
