# Payments

Este documento descreve as regras de pagamento. Ver também ADR 003 (`docs/decisions/003-payment-gateway.md`) para a decisão arquitetural de isolamento do gateway.

## Princípios

Nunca armazenar dados sensíveis de cartão (número, CVV, ou dados equivalentes). O sistema trabalha exclusivamente com tokens/identificadores fornecidos pelo gateway de pagamento.

O domínio de pagamento (`Payment`) não deve depender diretamente de detalhes de um gateway específico — a integração concreta fica isolada atrás de uma abstração, permitindo trocar de fornecedor sem contaminar o restante do domínio:

```text
Payment
    ↓
PaymentGateway
    ├── authorize
    ├── capture
    ├── refund
    └── verify_webhook
```

No MVP (Fase 7 do `ROADMAP.md`), apenas `authorize`/confirmação e `verify_webhook` são implementados. `refund` e captura em duas etapas são pós-MVP.

## Gateway de pagamento

`TODO — DECISION REQUIRED`: o gateway de pagamento concreto ainda não foi escolhido. Essa é uma decisão de negócio (custo, taxas, meios de pagamento suportados no Brasil, PIX, boleto, cartão), não uma decisão técnica que deva ser feita unilateralmente durante a implementação.

## Estados do pagamento

```text
pending
 ↓
authorized
 ↓
paid / captured
 ↓
failed
 ↓
refunded
 ↓
partially_refunded
```

O MVP cobre, no mínimo: `pending`, `authorized`/`paid` e `failed`. `refunded` e `partially_refunded` são pós-MVP (dependem da funcionalidade de refund).

Usar estados explícitos (enum), nunca uma combinação de booleanos (`paid = true`, `failed = false`, etc.) — isso cria combinações inválidas.

## Webhooks

Webhooks de pagamento devem ser:

* **autenticados** — validar que a notificação realmente vem do gateway antes de processá-la
* **idempotentes** — o mesmo evento recebido mais de uma vez não pode gerar efeito duplicado
* **persistidos** quando necessário para auditoria e para suportar a idempotência (ver `PaymentEvent` em `docs/domain.md`)
* **seguros para reprocessamento** (retry do lado do gateway)

O mesmo evento de webhook recebido duas vezes nunca pode:

* criar dois pedidos
* criar dois pagamentos
* debitar estoque duas vezes
* enviar dois e-mails de confirmação indevidamente

## Idempotência

Além dos webhooks, a criação do pagamento em si deve ser idempotente em relação ao pedido: uma tentativa de pagamento repetida para o mesmo `Order` não deve gerar múltiplas cobranças.

## Logs

Nunca registrar em logs: senha, token de autenticação, número de cartão, CVV, ou qualquer credencial. Usar `Rails.application.config.filter_parameters` para garantir isso. Ver também `docs/security.md`.

## Relação com o pedido

* Pagamento aprovado deve confirmar o pedido (`Order` transita para `confirmed` — ver `docs/checkout.md` e `docs/domain.md`).
* Pagamento recusado não deve confirmar o pedido nem debitar estoque de forma definitiva.

`TODO — DECISION REQUIRED`: a política exata de quanto tempo um pedido `pending` aguarda confirmação de pagamento antes de liberar o estoque reservado (se houver reserva) não está definida — depende da modelagem de estoque escolhida na Fase 8 e deve ser uma decisão de negócio.
