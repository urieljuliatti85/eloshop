# Domain

Este documento descreve as entidades do negócio e o que cada uma representa — não o esquema de banco definitivo (ver as migrations de cada fase no `ROADMAP.md`) nem a implementação.

Para o que já existe e o que ainda é apenas planejado, ver `ROADMAP.md`. Entidades marcadas `(MVP)` fazem parte do escopo mínimo (Fases 0–7); as demais são pós-MVP.

## Product `(MVP, escopo restrito)`

Representa um produto comercial vendido pela loja.

No MVP, todo produto é tratado com um único tipo de disponibilidade: estoque numérico padrão (`stock_quantity`). As demais formas abaixo são regras de negócio reais do domínio de artesanato, mas só passam a existir no sistema a partir da Fase 8 (Estoque avançado):

* peça única (uma unidade disponível)
* pequena tiragem
* feito sob encomenda (`made_to_order`)
* pré-venda (`pre_order`)
* personalizado
* vendido como conjunto

Ver `docs/inventory.md` para os tipos de disponibilidade e `docs/catalog.md` para os atributos do produto.

## ProductVariant `(pós-MVP — Fase 9)`

Representa uma combinação comercial específica de opções de um produto (ex.: tamanho + cor).

Nem todo produto possui variantes — um produto simples pode existir sem nenhuma `ProductVariant` associada (ver ADR 001, `docs/decisions/001-product-variants.md`). Nem toda combinação teoricamente possível entre opções existe de fato: cada variante deve representar uma combinação comercial real, cadastrada explicitamente.

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

## OrderItem `(MVP)`

Representa um produto comprado dentro de um pedido. Deve preservar snapshot de:

* nome do produto
* SKU
* preço unitário no momento da compra
* quantidade

Variante e personalização (quando essas funcionalidades existirem — pós-MVP) também devem ser preservadas como snapshot no `OrderItem`, nunca reconstruídas a partir da configuração atual do produto.

## Payment `(MVP)`

Representa uma tentativa/execução de pagamento vinculada a um `Order`. Ver `docs/payments.md` para estados e regras.

## PaymentEvent `(MVP)`

Representa um evento de webhook recebido do gateway de pagamento, usado para garantir idempotência (o mesmo evento não deve ser processado duas vezes). Ver `docs/payments.md`.

## Shipment `(pós-MVP — Fase 12)`

Representa o envio físico de um pedido, incluindo rastreamento. No MVP, o frete é um valor fixo/manual associado diretamente ao `Order`, sem uma entidade de envio própria.

## Coupon `(pós-MVP — Fase 13)`

Representa uma regra de desconto (percentual ou valor fixo), com data de validade e limite de uso.

`TODO — DECISION REQUIRED`: regras comerciais de desconto (percentual/valor máximo permitido, se cupons são cumulativos, regras de elegibilidade por produto/categoria) não estão definidas e devem ser decididas pelo negócio antes da Fase 13.

## Review `(pós-MVP — Fase 15)`

Representa uma avaliação de um produto por um cliente (nota, comentário, moderação, `verified_purchase`).

## Wishlist `(pós-MVP — Fase 15)`

Representa uma lista de produtos de interesse de um cliente. Não deve ser tratada como reserva de estoque.

## Artesão / Fabricante

`TODO — DECISION REQUIRED`: ainda não está definido se "artesão" é apenas um atributo informativo do `Product` (ex.: um campo de texto/relacionamento simples) ou se deve ser modelado como uma entidade comercial independente (o que aproximaria o sistema de um marketplace). Ver `docs/architecture.md`, seção "Multi-tenancy / marketplace". Não modelar como marketplace sem essa decisão explícita.
