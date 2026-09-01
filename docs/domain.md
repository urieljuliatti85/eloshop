# Domain

Este documento descreve as entidades do negócio e o que cada uma representa — não o esquema de banco definitivo (ver as migrations de cada fase no `ROADMAP.md`) nem a implementação.

Para o que já existe e o que ainda é apenas planejado, ver `ROADMAP.md`. Entidades marcadas `(MVP)` fazem parte do escopo mínimo (Fases 0–7); as demais são pós-MVP.

## Seller `(Fase 22, ADR 004)`

Representa um artesão como entidade comercial independente, dona do próprio catálogo (`Product`) e da parte de cada pedido que lhe cabe. Possui `name`, `slug`, estado explícito (`pending`, `approved`, `suspended`) e data de aprovação. O login usa `User.role = seller`, com `seller_id` obrigatório; admin da plataforma não possui vendedor. O painel deriva o escopo de `Current.user.seller`.

O cadastro nasce pendente e exige aprovação/KYC antes da publicação. O KYC é realizado pelo Mercado Pago, que exige identificação nível 6 para o split 1:1. O vendedor conecta a conta por OAuth; a EloShop guarda apenas o identificador externo, `live_mode`, datas e tokens cifrados — nunca RG, selfie ou comprovantes. Como a resposta OAuth pública não informa o nível KYC, um admin confirma explicitamente o requisito antes da aprovação, que aceita apenas uma conexão de produção. Desconectar a conta retorna o vendedor para `pending`.

## Product `(MVP + Fases 8, 15 e 22)`

Representa um produto comercial vendido pela loja.

Todo produto pertence obrigatoriamente a um `Seller`; a unicidade de `sku`/`slug` é escopada por vendedor no model e em índices únicos compostos. Produtos ativos só aparecem na vitrine e podem ser comprados quando o vendedor está aprovado. A URL pública inclui o vendedor: `/artesaos/:seller_slug/produtos/:slug`.

Desde a Fase 8, o produto tem um `availability_type`: `standard` (estoque numérico — cobre tanto produto comum quanto pequena tiragem), `one_of_a_kind` (peça única) ou `made_to_order` (feito sob encomenda, com prazo de produção). As formas abaixo ainda não existem no sistema:

* pré-venda (`pre_order`) — adiada na Fase 8, pendente de decisão de negócio (ver `docs/inventory.md`)
* vendido como conjunto

Ver `docs/inventory.md` para os tipos de disponibilidade e `docs/catalog.md` para os atributos do produto.

## ProductVariant `(Fase 9)`

Representa uma combinação comercial específica de opções de um produto (tamanho, cor e/ou material — pelo menos um obrigatório).

Nem todo produto possui variantes — um produto simples pode existir sem nenhuma `ProductVariant` associada (ver ADR 001, `docs/decisions/001-product-variants.md`). Nem toda combinação teoricamente possível entre opções existe de fato: cada variante deve representar uma combinação comercial real, cadastrada explicitamente (unicidade garantida por índice único no banco).

Possui SKU e estoque próprios (ADR 001) e também preço próprio (`price_cents`) — não há preço único compartilhado com o produto. Só é permitida em produtos `standard`; peça única e sob encomenda não suportam variante nesta fase. Um produto com variante nunca é comprado "cru": o `CartItem` sempre referencia uma `ProductVariant` específica, cuja disponibilidade (`active` + estoque) é a fonte de verdade — o `price_cents`/`stock_quantity` do `Product` deixam de ser usados nesse caso. Pode ser desativada (`active: false`) para sair de venda sem apagar histórico de pedidos que a referenciam.

## PersonalizationOption `(Fase 10)`

Representa um campo de personalização em texto livre definido por um produto (ex.: "Nome gravado", "Mensagem"), com limite de caracteres e obrigatoriedade próprios. Disponível para qualquer produto, independentemente de `availability_type` e de ter ou não `ProductVariant` — são eixos independentes (um produto pode ter tamanho via variante e nome gravado via personalização ao mesmo tempo).

Não afeta estoque, SKU ou preço — é só dado extra preservado no item. O valor escolhido é validado contra as opções atuais do produto no `CartItem` (campo obrigatório presente, dentro do limite de caracteres, pertencente ao produto) e depois gravado como snapshot self-contained (label + valor) no `OrderItem` — diferente da `ProductVariant`, não há referência de chave estrangeira do pedido de volta à opção, então excluir uma `PersonalizationOption` nunca afeta pedidos já feitos.

## Category `(pós-MVP — Fase 11)`

Representa a classificação comercial do produto, ou seja, como o cliente encontra o produto (ex.: Casa > Decoração). Pode ser hierárquica.

Categoria não deve ser confundida com técnica artesanal (ver `Technique` abaixo) — uma representa como o cliente navega, a outra representa como o produto foi feito.

## Material `(pós-MVP — Fase 11)`

Representa um material utilizado na produção de um produto (ex.: madeira, cerâmica, algodão). Um produto pode ter múltiplos materiais. Não deve ser armazenado como uma string livre única quando o domínio exigir busca, filtro ou reuso — nesse caso, modelar como entidade própria.

## Technique `(pós-MVP — Fase 11)`

Representa uma técnica artesanal utilizada (ex.: crochê, cerâmica, marcenaria, bordado). Usada para categorização, filtros, descoberta e SEO — não deve ser misturada com `Category`.

## Tag `(pós-MVP — Fase 11)`

Representa uma característica de descoberta (ex.: `feito-a-mao`, `sustentavel`, `minimalista`). Tags não substituem categorias.

## Customer `(MVP)`

Representa o cliente que compra na loja. Possui nome, e-mail (único) e credenciais de autenticação.

## Address `(MVP)`

Representa um endereço de entrega associado a um `Customer`.

Importante: o endereço vinculado ao pedido não é uma referência ao endereço atual do cliente, e sim um snapshot capturado no momento do checkout (ver `Order` abaixo e `docs/checkout.md`) — o endereço cadastrado do cliente pode mudar depois sem afetar pedidos já feitos.

## Cart / CartItem `(MVP)`

Representa o pedido em montagem, antes do checkout.

O carrinho **não é** uma reserva definitiva de estoque, salvo quando isso for explicitamente implementado (não é o caso no MVP). Um produto pode se tornar indisponível enquanto está no carrinho de um cliente — a disponibilidade é sempre revalidada no checkout.

## Order `(MVP)`

Representa uma compra realizada — o registro histórico da transação.

Depois de criado, o `Order` deve preservar todas as informações necessárias para reconstruir exatamente o que foi comprado, mesmo que os dados atuais do produto, do cliente ou do endereço mudem depois. Isso inclui, no mínimo:

```text
Order
├── OrderItems (snapshot de produto e preço)
├── Customer (referência)
├── ShippingAddressSnapshot (snapshot, não referência)
├── Payment
└── Metadata (subtotal, frete, total)
```

Elementos como cupom aplicado (`Discounts`) e envio/rastreamento (`Shipment`) são adicionados ao `Order` conforme as fases pós-MVP correspondentes forem implementadas.

Implementado na Fase 23: o `Order` principal agrega `SellerOrder`s, que isolam vendedor, totais, status, fulfillment, comissão, reembolso e repasse. Cada `OrderItem` e `Shipment` pertence ao seu `SellerOrder`. No primeiro lançamento, cada checkout aceita um vendedor e cria exatamente um `SellerOrder`; múltiplos vendedores continuam condicionados ao acesso comercial ao split 1:N do Mercado Pago.

## OrderItem `(MVP)`

Representa um produto comprado dentro de um pedido. Deve preservar snapshot de:

* nome do produto
* SKU
* preço unitário no momento da compra
* quantidade

Variante (Fase 9: SKU, tamanho, cor, material) e personalização (Fase 10: label e valor de cada campo preenchido) também são preservadas como snapshot no `OrderItem`, nunca reconstruídas a partir da configuração atual do produto.

## Payment `(MVP; split planejado — Fase 23)`

Representa uma tentativa/execução de pagamento vinculada a um `Order`. Ver `docs/payments.md` para estados e regras.

Implementado na Fase 23: split 1:1 com comissão da plataforma de 15% sobre o subtotal dos produtos após descontos, excluindo frete. O `Payment` preserva comissão, tarifa do Mercado Pago e valores reembolsados separadamente. `PaymentRefund` fornece auditoria e idempotência; reembolsos revertem a comissão proporcionalmente.

## PaymentEvent `(MVP)`

Representa um evento de webhook recebido do gateway de pagamento, usado para garantir idempotência (o mesmo evento não deve ser processado duas vezes). Ver `docs/payments.md`.

## Shipment `(Fase 12)`

Representa o envio físico de um pedido, incluindo transportadora, modalidade,
valor calculado, prazo estimado, status e código de rastreamento. É criado em
status `pending` junto com o pedido. A integração operacional com uma
transportadora externa continua pendente de decisão de negócio.

Planejado (ADR 004, Fase 23): quando um pedido envolver mais de um vendedor, cada um poderá precisar de fulfillment/rastreamento próprio — hoje `Shipment` é sempre único por `Order` (`has_one`).

## Coupon `(Fase 13)`

Representa uma regra de desconto: percentual (1-100%, sem teto) ou valor fixo em centavos — um único tipo por cupom, nunca os dois. `Coupon#valid_for?(subtotal_cents)` é a fonte única de verdade para elegibilidade (ativo, dentro da janela `starts_at`/`expires_at`, `uses_count < max_uses` quando houver limite, subtotal mínimo atingido quando houver). `Coupon#discount_cents_for(subtotal_cents)` nunca deixa o desconto ultrapassar o subtotal (evita total negativo).

Decisões de negócio confirmadas: um cupom por pedido (não cumulativo); válido para a loja toda (sem restrição por produto/categoria); limite de uso é um total global opcional (`max_uses`), sem limite por cliente; validade por `starts_at`/`expires_at` opcionais mais um campo `active` para desativação manual.

O cupom "aplicado" fica associado ao `Cart` (`belongs_to :coupon, optional: true`) até o checkout. `Checkout::CreateOrder` trava o cupom (`lock!`) na mesma transação do estoque e revalida contra o subtotal final antes de gravar `discount_cents`/`coupon_id` no `Order` e incrementar `uses_count` — isso evita que dois checkouts simultâneos ultrapassem o `max_uses` de um cupom com uso limitado (mesmo princípio de concorrência do estoque, ver `docs/inventory.md`).

## Review `(Fase 15)`

Representa uma avaliação de um produto por um cliente (nota 1-5, comentário, moderação, `verified_purchase`). Uma review por cliente por produto.

`status` (`pending`/`approved`/`rejected`, default `pending`) é a moderação — só reviews `approved` aparecem na loja; decisão de negócio: aprovação do admin é obrigatória antes de publicar, nunca automática. Qualquer cliente autenticado pode avaliar (não é exigido ter comprado); `verified_purchase` é um selo calculado automaticamente (o cliente tem algum pedido `confirmed` contendo o produto avaliado — não há status "entregue" ainda, ver `Order` em `docs/checkout.md`), não um requisito de acesso.

## Wishlist `(Fase 15)`

Representa a lista de produtos de interesse de um cliente, via `WishlistItem` (customer + product, único por par). Só disponível para clientes autenticados — decisão de negócio, sem versão para visitante como o `Cart`.

Não deve ser tratada como reserva de estoque. Produtos indisponíveis continuam aparecendo na lista (não são escondidos) — o cliente decide se remove.

## Produtos relacionados

"Você também pode gostar" na página do produto: outros produtos ativos, mais recentes primeiro, excluindo o atual — decisão de negócio, já que ainda não existem categorias/tags (Fase 11) para uma recomendação mais relevante. Não é uma entidade própria, só um método de consulta em `Product`.

## Artesão / Vendedor

Ver `Seller`, no início deste documento — a decisão de marketplace já foi tomada (ADR 004).
