# Shipping

Este documento descreve as regras de frete e prazo de entrega.

## Composição do prazo total

O sistema deve sempre separar conceitualmente:

```text
Tempo de produção
+
Tempo de preparação
+
Tempo de transporte
```

"Tempo de produção" (relevante apenas para produtos feitos sob encomenda — ver `docs/inventory.md`) nunca deve ser confundido com "tempo de transporte". Um produto sob encomenda deve exibir ao cliente, no mínimo, o prazo de produção antes da compra, e esse prazo deve ser registrado no pedido no momento da compra.

## Escopo do MVP

No MVP (Fase 5 do `ROADMAP.md`), não há cálculo real de frete nem produtos sob encomenda. O frete é um valor fixo/manual associado ao pedido, apenas para permitir que o fluxo de checkout seja concluído de ponta a ponta.

**Decisão de negócio**: frete fixo de R$ 15,00 (`Checkout::CreateOrder::SHIPPING_CENTS`) para qualquer pedido, até a Fase 12 trazer o cálculo real via Correios.

## Frete real (Fase 12)

Quando implementado, o cálculo de frete pode depender de:

* CEP de destino
* peso do produto
* dimensões
* quantidade de itens
* tipo de produto (ex.: embalagem especial — ver `docs/domain.md`)
* região
* transportadora
* modalidade de envio

Nesta fase, o cálculo inicial é feito por `Shipping::Calculator`, sem dependência
de API externa: usa CEP, peso total dos itens e quantidade. O resultado preserva
transportadora, modalidade, valor e prazo estimado no `Shipment` associado ao
`SellerOrder` do artesão. Assim, frete e fulfillment já estão isolados por
vendedor, embora o primeiro lançamento aceite somente um vendedor por checkout.
O provedor é isolado para permitir a integração futura com Correios,
agregador ou transportadora privada quando essa decisão de negócio for tomada.

O produto possui peso e dimensões opcionais. O peso participa do cálculo; as
dimensões ficam registradas para o próximo provedor que exigir cubagem. CEP
inválido ou peso acima do limite de envio tornam o frete indisponível e impedem
a criação do pedido.

## Endereço de origem do ateliê

Desde 2026-09-06 o `Seller` tem endereço de origem (`origin_zip_code`,
`origin_street`, `origin_number`, `origin_complement`, `origin_neighborhood`,
`origin_city`, `origin_state`), editável pelo vendedor em `/painel/atelie`. É
de onde a peça é despachada — nenhum cálculo real de frete funciona sem o CEP
de origem, qualquer que seja a transportadora escolhida.

Os campos são **opcionais** por ora: os vendedores já cadastrados não os têm, e
exigi-los invalidaria o catálogo deles. Mas o preenchimento é tudo-ou-nada
(`Seller#origin_address_started?`): meio endereço não despacha nada. O CEP é
normalizado para 8 dígitos, como o CEP de destino que o `Shipping::Calculator`
já recebe.

`Seller#origin_address_complete?` responde se o ateliê está pronto para
despachar. **Tornar o endereço obrigatório é decisão para quando o frete real
for ligado** — provavelmente como pré-requisito de aprovação do vendedor, o que
exige backfill dos existentes.

Regras de frete não devem ser implementadas diretamente em controllers — devem ficar isoladas no domínio de Shipping.

**Provedor definido em 2026-09-06: Melhor Envio** — ver o **ADR 005**
(`docs/decisions/005-shipping-provider.md`), que registra por que ele foi
escolhido, o que a documentação dele confirma e como a integração se divide em
três etapas. Nenhuma linha foi escrita ainda.

`TODO — DECISION REQUIRED`: seguem pendentes, e travam apenas as Etapas 2 e 3
(etiqueta e rastreio), **se existe frete grátis** — a partir de qual valor e
por conta de quem — e **quem absorve a diferença** quando o frete real sai mais
caro que o cobrado no checkout.

## Embalagem

Produtos artesanais podem ter necessidades especiais de embalagem (peso da embalagem, dimensões, fragilidade, necessidade de proteção, instruções especiais). Este domínio não deve ser adicionado até existir uma necessidade real e concreta — não faz parte do MVP nem está agendado em uma fase específica do roadmap ainda.

`TODO — DECISION REQUIRED`: se e quando embalagem especial se tornar uma necessidade real do negócio, isso deve ser adicionado ao `ROADMAP.md` como uma fase própria antes de ser implementado.

## Rastreamento

`Shipment` é criado com o `SellerOrder` em status `pending`, preservando transportadora,
modalidade, preço e prazo estimado. Código de rastreamento e transições de envio
serão preenchidos quando houver integração operacional com a transportadora.
