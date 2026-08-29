# Inventory

Este documento descreve as regras de estoque e disponibilidade. É um dos documentos mais sensíveis do domínio de artesanato: erros aqui resultam em vender o mesmo item mais de uma vez.

## Tipos de estoque (visão completa do domínio)

### Standard `(MVP)`

Produto com estoque tradicional, controlado por uma quantidade numérica (`stock_quantity`). É o único tipo suportado no MVP (ver `docs/domain.md`, seção `Product`).

### One of a Kind `(pós-MVP — Fase 8)`

Possui uma única unidade disponível. Depois da venda, o produto deve ser marcado como `sold_out` — não pode voltar a ficar disponível automaticamente.

### Made to Order `(pós-MVP — Fase 8)`

Não depende de estoque físico pré-existente; a produção começa após a compra. Requer prazo de produção estimado, apresentado ao cliente antes da compra e registrado no pedido no momento da compra (ver `docs/shipping.md` para a relação entre prazo de produção e prazo de transporte).

### Pre Order `(pós-MVP — Fase 8)`

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

No MVP, apenas `in_stock` e `out_of_stock` são relevantes (derivados diretamente de `stock_quantity`). Os demais dependem dos tipos de estoque pós-MVP acima.

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

`TODO — DECISION REQUIRED`: o mecanismo específico de locking (lock pessimista via `SELECT ... FOR UPDATE`, lock otimista via coluna de versão, ou constraint de banco que rejeite estoque negativo) não está definido. Deve ser escolhido durante a implementação da Fase 5 (Checkout), com base em teste de concorrência real, e documentado aqui como ADR quando decidido.

## Relação com o carrinho e o checkout

O carrinho não reserva estoque (ver `docs/domain.md`, seção `Cart`). A validação e a baixa de estoque acontecem no checkout, de forma atômica junto com a criação do pedido (ver `docs/checkout.md`).

## Movimentações de estoque

`TODO — DECISION REQUIRED`: ainda não está definido se o sistema precisa de um histórico explícito de movimentações de estoque (entradas/saídas manuais do administrador, ajustes) como uma entidade própria, ou se a coluna `stock_quantity` no `Product` é suficiente para o volume de negócio esperado. Isso é relevante para a Fase 8 (Estoque avançado).
