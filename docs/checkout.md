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
Carrinho → Identificação/Endereço → Escolha da entrega → Resumo → Pagamento → Pedido
```

A etapa "Cupons" (Fase 13) não é uma página própria do checkout: o cupom é aplicado no carrinho (`POST /cart/apply_coupon`) e revalidado no momento da finalização, junto com estoque e frete — ver `Coupon` em `docs/domain.md`. "Personalizações" (Fase 10) segue o mesmo padrão: a escolha acontece antes, na página do produto/ao adicionar ao carrinho (ver `PersonalizationOption` em `docs/domain.md`) — o resumo do pedido só exibe o que já foi escolhido, não pede pra preencher de novo.

Cada produto pode oferecer entrega nacional por preço/prazo fixos e retirada
gratuita. No carrinho, os valores são somados por unidade e prevalece o maior
prazo; retirada só é possível quando todos os produtos a permitem. O cliente
escolhe uma das opções exibidas, mas o formulário envia somente
`shipping_quote_id`: `Checkout::CreateOrder` reconstrói as opções no servidor e
rejeita qualquer identificador que não tenha sido ofertado.

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
* quem recebe: nome, CPF e telefone (ver abaixo)

Pedidos já criados nunca devem depender dos dados atuais do produto, do cliente ou do endereço (ver `docs/domain.md`, seção `Order`).

## Destinatário (2026-11-05)

A etiqueta da SuperFrete exige nome e CPF de quem recebe (`to.document`, confirmado no sandbox — ver `docs/shipping.md` e ADR 005, "Etapa 2 e 3"). O checkout tem a seção **Quem vai receber** (`Checkout::Recipient`):

* **nome** obrigatório, preenchido com o do último pedido ou o da conta;
* **CPF** obrigatório **só com entrega** — a retirada no ateliê não gera etiqueta, e nela o CPF nem é gravado. Validado pelo módulo 11 (`Cpf.valid?`, o mesmo do cadastro do ateliê). Fica cifrado no `Order` (`recipient_cpf_ciphertext`, salt próprio) e nunca é pré-preenchido;
* **telefone** opcional (os serviços dos Correios que oferecemos não exigem), guardado só em dígitos.

Quem decide é `Checkout::CreateOrder`, depois da cotação (a modalidade diz se há entrega) e antes de travar estoque: `InvalidRecipient` faz o checkout voltar ao formulário (422) com o que foi digitado, endereço e modalidade mantidos. O navegador liga e desliga o `required` do CPF conforme a modalidade marcada, mas é só conveniência.

**Quem vê o CPF:** o ateliê vê o CPF inteiro só enquanto o pedido está pago e aguarda envio (`Shipment#awaiting_dispatch?`), que é quando compra a etiqueta; antes e depois, mascarado. O admin vê mascarado; o comprador, na página do pedido e nos e-mails, vê só o nome. Pedidos anteriores não têm destinatário: o nome exibido é o do comprador (`Order#recipient_display_name`).

## Idempotência

O checkout é uma operação que pode ser repetida (duplo clique, timeout seguido de retry, reenvio de formulário) e deve ser idempotente: a mesma tentativa de checkout não pode gerar dois pedidos.

**Decisão (Fase 5)**: chave gerada no servidor (`SecureRandom.hex`) e guardada na sessão HTTP quando o cliente entra na tela de revisão do pedido (`OrdersController#new`); usada na criação do pedido e removida da sessão após sucesso. `orders.idempotency_key` tem índice único no banco — uma tentativa duplicada (inclusive sob concorrência real, via `ActiveRecord::RecordNotUnique`) retorna o pedido já criado em vez de duplicar. Ver `Checkout::CreateOrder`.

## Marketplace

Desde a Fase 22, o carrinho aceita produtos de um único vendedor. A validação acontece ao adicionar o item e novamente dentro da transação de `Checkout::CreateOrder`, cobrindo carrinhos legados e concorrência. Isso preserva o lançamento com split 1:1 do Mercado Pago.

O `Order` principal agrega `SellerOrder`s para dividir frete/fulfillment, status, cancelamento e repasse por artesão. O primeiro lançamento cria exatamente um `SellerOrder`, no mesmo lock/transação que cria o pedido e baixa o estoque. Checkout multi-vendedor depende de acesso comercial ao split 1:N; não são usados múltiplos PIX nem repasse manual pela plataforma.

**Quem paga o cupom: o vendedor.** O cupom é da plataforma e não tem escopo de vendedor, mas o desconto sai do repasse de quem vende: `seller_amount_cents = total_cents - platform_fee_cents`, e a comissão incide sobre `subtotal - desconto`. A plataforma só deixa de receber a comissão sobre o valor descontado: com cupom de 10% num pedido de R$ 300 e comissão de 15%, o desconto é de R$ 30, o vendedor recebe R$ 25,50 a menos e a plataforma, R$ 4,50 a menos. Essa regra está no código, mas não no texto dos `SellerTerms` do ateliê; levá-la aos termos fica para a revisão com o advogado. Desde a Fase 25 (ADR 007), o cupom tem escopo por tipo de vendedor (`Coupon#seller_kind`, padrão `atelier` no banco e no model): `Coupon#valid_for?` exige o vendedor do carrinho (`seller:`), e o tipo é conferido ao aplicar, a cada cálculo do desconto e dentro da trava do checkout. Cupom de ateliê não vale em carrinho de distribuidor, e vice-versa.

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
