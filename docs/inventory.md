# Inventory

Este documento descreve as regras de estoque e disponibilidade. É um dos documentos mais sensíveis do domínio de artesanato: erros aqui resultam em vender o mesmo item mais de uma vez.

## Tipos de estoque (visão completa do domínio)

### Standard `(implementado — Fase 1)`

Produto com estoque tradicional, controlado por uma quantidade numérica (`stock_quantity`). Cobre tanto o produto comum quanto "pequena tiragem" (a mesma coisa, só com `stock_quantity > 1`) — não é um tipo à parte.

### One of a Kind `(implementado — Fase 8)`

`Product.availability_type: "one_of_a_kind"`. Possui uma única unidade disponível (`stock_quantity` limitado a no máximo 1 por validação). Depois da venda, o produto vai para `sold_out` e **não pode voltar a `active`** — a transição é bloqueada no modelo (`Product::ONE_OF_A_KIND_STATUS_TRANSITIONS`), diferente de um produto `standard`, que pode ser reabastecido normalmente.

### Made to Order `(implementado — Fase 8)`

`Product.availability_type: "made_to_order"`. Não depende de estoque físico — `available_for_purchase?` ignora `stock_quantity` para este tipo, e o checkout não debita estoque. Exige prazo de produção (`production_time_min_days`/`production_time_max_days`), apresentado ao cliente antes da compra e gravado como snapshot em `OrderItem#production_time_snapshot` no momento da compra (ver `docs/shipping.md` para a relação entre prazo de produção e prazo de transporte — continuam sendo coisas separadas).

### Pre Order `(pós-MVP — adiado na Fase 8)`

Venda antecipada de um produto ainda não disponível fisicamente.

`TODO — DECISION REQUIRED`: regras comerciais de pré-venda (prazo máximo, política de cancelamento caso a produção não se concretize) não estão definidas.

## Tipos de disponibilidade

O produto pode assumir diferentes estados de disponibilidade, além do ciclo de vida de catálogo (`docs/catalog.md`):

```text
in_stock
low_stock
out_of_stock
made_to_order
pre_order
discontinued
```

No MVP, apenas `in_stock` e `out_of_stock` eram relevantes (derivados diretamente de `stock_quantity`). Desde a Fase 8, `made_to_order` também é real (disponibilidade derivada só do status `active`, sem depender de estoque). `pre_order` continua adiado.

A disponibilidade deve ter uma única fonte de verdade centralizada. Não espalhar verificações equivalentes a `product.stock_quantity > 0` por controllers, views e services distintos — toda decisão de "este produto pode ser comprado agora?" deve passar pelo mesmo ponto do domínio.

## Concorrência

Estoque deve ser tratado como uma operação concorrente desde o MVP. Nunca implementar a baixa de estoque como uma leitura seguida de escrita não protegida:

```ruby
if product.stock_quantity > 0
  product.stock_quantity -= 1
  product.save
end
```

Esse padrão permite que dois clientes comprem a última unidade simultaneamente. É necessário usar transação e um mecanismo de locking/atomicidade adequado.

Caso mais crítico do domínio: um produto com `stock_quantity = 1` (ou, pós-MVP, `one_of_a_kind`) sendo disputado por dois clientes em checkout simultâneo — o sistema não pode vender a mesma peça duas vezes.

**Decisão (Fase 5)**: lock pessimista via `SELECT ... FOR UPDATE` (`product.lock!` dentro da transação de criação do pedido, em `Checkout::CreateOrder`), combinado com uma constraint de banco `CHECK (stock_quantity >= 0)` como defesa em profundidade — nunca depender só da validação Rails. Quando um carrinho tem mais de um item, os produtos são bloqueados em ordem estável (`product_id` crescente) para evitar deadlock entre transações concorrentes. Validado com teste de concorrência real usando threads (`test/services/checkout/create_order_concurrency_test.rb`): duas tentativas simultâneas de compra da última unidade de um produto — apenas uma é bem-sucedida, a outra falha, e o estoque nunca fica negativo.

**Extensão (Fase 9 — variantes)**: quando o item do carrinho tem `ProductVariant`, o estoque que importa é o da variante, não o do produto — `Checkout::CreateOrder` bloqueia (`lock!`) o `Product` (para revalidar status) e a `ProductVariant` (para revalidar estoque), na mesma ordem estável já usada (por `product_id`, depois `product_variant_id`). Mesma constraint `CHECK (stock_quantity >= 0)` na tabela `product_variants`. Teste de concorrência dedicado (`test/services/checkout/create_order_variant_concurrency_test.rb`) replica o cenário da última unidade, agora no nível da variante.

## Relação com o carrinho e o checkout

O carrinho não reserva estoque (ver `docs/domain.md`, seção `Cart`). A validação e a baixa de estoque acontecem no checkout, de forma atômica junto com a criação do pedido (ver `docs/checkout.md`).

## Movimentações de estoque

`TODO — DECISION REQUIRED`: ainda não está definido se o sistema precisa de um histórico explícito de movimentações de estoque (entradas/saídas manuais do administrador, ajustes) como uma entidade própria, ou se a coluna `stock_quantity` no `Product` é suficiente para o volume de negócio esperado. Isso é relevante para a Fase 8 (Estoque avançado).
