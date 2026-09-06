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

No MVP (Fase 7 do `ROADMAP.md`), foram implementados `authorize`/confirmação e `verify_webhook`. A Fase 23 acrescentou `refund` idempotente; captura em duas etapas continua fora do escopo.

## Gateway de pagamento

**Decisão (Fase 7 — provisória)**: nenhum gateway real havia sido escolhido, e o MVP usou um gateway simulado (`Gateways::FakeGateway`) atrás da mesma abstração que um gateway de verdade usaria.

**Decisão (Fase 20, Etapa B)**: o gateway real é o **Mercado Pago**, começando **apenas por PIX** — sem cartão nem boleto, o que evita lidar com dado sensível de cartão e tokenização no front nesta primeira volta.

### Seleção do gateway

`Gateways.build` decide qual adapter usar a partir de `PAYMENT_GATEWAY`. Em desenvolvimento e teste, o default é o simulado. Em produção, configuração ausente ou `fake` falha explicitamente: uma loja no ar nunca pode aprovar pedidos sem cobrar. O gateway real só é habilitado com `PAYMENT_GATEWAY=mercado_pago` e suas credenciais.

Um nome desconhecido levanta `Gateways::UnknownGateway` em vez de cair no simulado: um erro de digitação na variável faria a loja "aprovar" pagamentos sem cobrar nada.

### Credenciais

Em variáveis de ambiente, não nas credentials do Rails, para permitir rotação sem novo deploy — pagamento é onde girar uma chave comprometida precisa ser rápido:

* `MERCADO_PAGO_WEBHOOK_SECRET`

O access token usado para cobrar e reembolsar pertence ao vendedor e vem da conexão OAuth cifrada em `Seller`; não existe token global da plataforma para receber o valor integral. Tokens próximos do vencimento são renovados sob lock antes da chamada ao gateway.

### Interface do gateway

```text
name             → identificador gravado em Payment#gateway
authorize(order:, idempotency_key:, application_fee_cents:) → Gateways::Intent
refund(payment:, amount_cents:, idempotency_key:) → Gateways::RefundIntent
verify_webhook(request) → true/false
webhook_event(request)  → { event_id:, external_id:, status:, processor_fee_cents: }
payment_status(external_id:) → "approved" | "declined" | "pending"
```

`Gateways::Intent` carrega `external_id` e, quando o meio for PIX, o QR code e a expiração. Os campos de PIX estão no `Intent` genérico, não no adapter, porque QR de PIX é conceito do meio de pagamento brasileiro e não do Mercado Pago — outro provedor preencheria os mesmos campos.

### Webhook

A notificação do Mercado Pago **não carrega o status de forma confiável**: ela avisa que o pagamento X mudou e espera que a aplicação consulte a API. Por isso `webhook_event` faz uma chamada de volta ao gateway. Sem isso, bastaria forjar um POST para marcar um pedido como pago.

A autenticidade vem de HMAC-SHA256 sobre um manifesto (`id` + `x-request-id` + `ts`), comparado de forma timing-safe — diferente do segredo simples do gateway fake.

O `event_id` combina pagamento e status (`mp-<id>-<status>`) porque o Mercado Pago notifica o mesmo pagamento a cada mudança; usar só o id faria a segunda notificação ser descartada como duplicata por `Payments::ProcessWebhook`.

O endpoint a configurar no painel é `POST /webhooks/payments`.

### O que ainda não foi verificado

O adapter e seus testes existem, mas **a integração nunca rodou contra o sandbox do Mercado Pago** — falta credencial. Os testes stubam HTTP e verificam o contrato do adapter (o que envia, o que devolve, o que recusa), não a API real. Antes de ligar `PAYMENT_GATEWAY=mercado_pago` em produção, é obrigatório um teste ponta a ponta no sandbox.

`TODO — DECISION REQUIRED`: prazo de expiração do PIX e o que acontece com o pedido quando ele expira. Hoje o pedido fica `pending` indefinidamente.

### Renovação e acompanhamento do PIX

As três lacunas identificadas antes do teste no sandbox foram fechadas:

1. `Payments::Authorize` reaproveita um pagamento `pending` somente enquanto o PIX ainda está válido. Ao abrir novamente a etapa de pagamento depois da expiração, a tentativa anterior vira `failed` e uma nova cobrança é criada. Isso não cancela o pedido, que continua `pending` — a política de expiração do pedido inteiro continua sendo uma decisão de negócio separada.
2. Cada `Payment` possui sua própria `idempotency_key`. A tentativa é persistida no estado interno `processing` antes da chamada externa; se houver timeout ou queda depois que o Mercado Pago receber a requisição, o retry retoma o mesmo registro e a mesma chave. Uma tentativa posterior a um QR expirado recebe outra chave.
3. A página do PIX consulta periodicamente um endpoint somente de leitura, autenticado e escopado ao dono do pedido. O bloco de pagamento reflete `paid`/`failed` assim que o webhook atualizar o banco, sem criar cobranças durante o polling. Se o QR vencer com a página aberta, o polling para e a interface oferece uma nova tentativa.

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

O fluxo cobre `pending`, `authorized`/`paid`, `failed`, `partially_refunded` e `refunded`.

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

Além dos webhooks, a criação do pagamento é idempotente por tentativa. Retries técnicos da mesma tentativa conservam a chave; uma tentativa comercialmente nova, necessária depois de recusa ou expiração, usa outra chave. O lock do pedido impede que requisições concorrentes criem registros de tentativa independentes.

## Logs

Nunca registrar em logs: senha, token de autenticação, número de cartão, CVV, ou qualquer credencial. Usar `Rails.application.config.filter_parameters` para garantir isso. Ver também `docs/security.md`.

## Marketplace

O vínculo do vendedor com o Mercado Pago foi introduzido na Fase 22 via OAuth Authorization Code com PKCE (S256) — a aplicação Marketplace exige PKCE nas configurações avançadas, e sua ausência produz `invalid_client` (HTTP 400) no `/oauth/token`, o mesmo erro de uma credencial errada. O vendedor precisa ter conta Mercado Pago com KYC nível 6, requisito confirmado manualmente pela plataforma porque a resposta OAuth pública não informa esse nível. A aplicação armazena somente o identificador do vendedor, datas e tokens cifrados; documentos permanecem no Mercado Pago. Para ativar o fluxo são necessárias `MERCADO_PAGO_MARKETPLACE_APP_ID`, `MERCADO_PAGO_MARKETPLACE_CLIENT_SECRET` e `MERCADO_PAGO_MARKETPLACE_REDIRECT_URI`.

`MERCADO_PAGO_MARKETPLACE_CLIENT_SECRET` **não** é o Access Token (nem o de teste, nem o de produção) — é o par `Client ID`/`Client Secret` que só aparece na tela "Credenciais de produção" da aplicação, mesmo para autenticar contra o sandbox (`client_id`/`client_secret` identificam a aplicação; `test_token=true` no corpo da requisição é o que sinaliza que o resultado deve ser uma conta de teste). Usar o Access Token no lugar do Client Secret também produz `invalid_client`.

O sandbox é opt-in por `MERCADO_PAGO_MARKETPLACE_SANDBOX=true`. Nesse modo, a troca do authorization code envia o parâmetro documentado `test_token=true` e o painel identifica explicitamente que a conta TESTUSER não permite aprovação nem vendas reais. A variável vem somente do ambiente, nunca da requisição do vendedor. Produção é o padrão seguro e não envia `test_token`. As credenciais da aplicação Marketplace de testes devem ficar separadas das produtivas.

O fluxo completo (autorização → callback → troca de token → conexão do `Seller`) já rodou ponta a ponta no sandbox com uma conta TESTUSER do tipo Vendedor, confirmando PKCE e o Client Secret corretos.

Na Fase 23, pagamentos passaram a suportar split entre vendedor e plataforma. `Payments::Authorize` usa o access token OAuth do vendedor e envia `application_fee` no PIX. A comissão é 15% do subtotal dos produtos após descontos, sem frete; a tarifa do Mercado Pago é registrada separadamente e suportada pelo vendedor. Reembolsos são operados apenas pelo admin da plataforma, usam chave de idempotência, preservam cada tentativa em `PaymentRefund` e revertem a comissão proporcionalmente sem erro acumulado de arredondamento. No primeiro lançamento, cada checkout tem um único vendedor/`SellerOrder` e usa o split público 1:1; multi-vendedor depende de habilitação comercial do split 1:N. Não são criados múltiplos PIX para uma compra nem repasses manuais a partir da conta da plataforma.

## Relação com o pedido

* Pagamento aprovado deve confirmar o pedido (`Order` transita para `confirmed` — ver `docs/checkout.md` e `docs/domain.md`).
* Pagamento recusado não deve confirmar o pedido nem debitar estoque de forma definitiva.

`TODO — DECISION REQUIRED`: a política exata de quanto tempo um pedido `pending` aguarda confirmação de pagamento antes de liberar o estoque reservado (se houver reserva) não está definida — depende da modelagem de estoque escolhida na Fase 8 e deve ser uma decisão de negócio.
