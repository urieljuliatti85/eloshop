# ADR 001 — Product Variants

## Status

Accepted

## Context

Alguns produtos possuem combinações de:

- tamanho
- cor
- material

Nem todos os produtos possuem variantes.

## Decision

Utilizar `ProductVariant` somente quando
o produto possuir variações comerciais reais.

Produtos simples continuam sendo representados
diretamente por `Product`.

## Alternatives

### Uma variante obrigatória para todo produto

Rejeitada.

Criaria complexidade desnecessária para produtos simples.

### JSON dentro de Product

Rejeitada.

Dificulta:

- estoque
- SKU
- filtros
- consultas
- constraints

## Consequences

Produtos simples continuam simples.

Produtos complexos podem possuir variantes
independentes com SKU e estoque próprios.