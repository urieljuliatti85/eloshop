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

`TODO — DECISION REQUIRED`: o valor fixo de frete a ser usado no MVP (ou se será R$ 0,00 / frete grátis temporário) não está definido — é uma decisão de negócio, não técnica.

## Frete real (pós-MVP — Fase 12)

Quando implementado, o cálculo de frete pode depender de:

* CEP de destino
* peso do produto
* dimensões
* quantidade de itens
* tipo de produto (ex.: embalagem especial — ver `docs/domain.md`)
* região
* transportadora
* modalidade de envio

Regras de frete não devem ser implementadas diretamente em controllers — devem ficar isoladas no domínio de Shipping.

`TODO — DECISION REQUIRED`: qual(is) transportadora(s) ou serviço(s) de cálculo de frete serão integrados (ex.: Correios, transportadora privada, serviço agregador) não está definido.

## Embalagem

Produtos artesanais podem ter necessidades especiais de embalagem (peso da embalagem, dimensões, fragilidade, necessidade de proteção, instruções especiais). Este domínio não deve ser adicionado até existir uma necessidade real e concreta — não faz parte do MVP nem está agendado em uma fase específica do roadmap ainda.

`TODO — DECISION REQUIRED`: se e quando embalagem especial se tornar uma necessidade real do negócio, isso deve ser adicionado ao `ROADMAP.md` como uma fase própria antes de ser implementado.

## Rastreamento

Rastreamento de envio (`Shipment`) é pós-MVP (Fase 12) e depende da integração com a transportadora escolhida.
