# ADR 002 — Inventory Strategy

## Status

Accepted

## Context

O catálogo possui:

- produtos comuns
- pequenas tiragens
- peças únicas
- produtos sob encomenda

## Decision

O sistema deve suportar diferentes estratégias
de disponibilidade.

Estoque físico não deve ser usado para representar
produtos feitos sob encomenda.

## Consequences

A disponibilidade comercial e o estoque físico
não são necessariamente a mesma coisa.