# ADR 003 — Payment Gateway

## Status

Accepted

## Context

O sistema precisa processar pagamentos sem
acoplar o domínio a um fornecedor específico.

## Decision

Isolar o gateway atrás de uma interface própria.

```text
Payment
   ↓
PaymentGateway
   ↓
Gateway Adapter