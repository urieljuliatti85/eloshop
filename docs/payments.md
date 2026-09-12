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

**Decisão (Fase 20, Etapa B)**: o gateway real é o **Mercado Pago**, começando **apenas por PIX** — sem cartão nem boleto, o que evita lidar com dado sensível de cartão e tokenização no front nesta primeira volta. A Fase 24 (planejada, não iniciada) revisita cartão de crédito via Checkout Bricks, mantendo PIX sem regressão; ver o corpo da fase no `ROADMAP.md`.

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

### Cartão de crédito (Fase 24)

`authorize` aceita `payment_method:` (`"pix"`/`"credit_card"`), `card_token:` e `installments:`. PIX permanece assíncrono (`Intent#status` nasce `"pending"`, a confirmação chega por webhook); cartão é síncrono — o Mercado Pago aprova ou recusa **na própria resposta HTTP**, e `Intent#status` já vem `"approved"`/`"declined"`. `Payments::Authorize` sempre grava `Payment#status` como `"pending"` na criação (o vocabulário do gateway não é um valor válido do enum) e, quando `intent.status` indica um desfecho síncrono, chama `Payments::ProcessWebhook` internamente com um `event_id` sintético (`sync-<external_id>-<status>`) — reaproveitando a mesma lógica de confirmação de pedido que a notificação real do gateway dispara depois; a idempotência por `gateway_event_id` absorve a duplicidade sem duplicar efeito.

A tokenização acontece no navegador via **Checkout Bricks** (Card Payment Brick, `sdk.mercadopago.com/js/v2`) — nenhum dado de cartão trafega pelo backend, só o token gerado pelo Brick. Isso exige a **Public Key** do vendedor (`Seller#mercado_pago_public_key`), diferente do Access Token: é pública por design e não é cifrada no banco, ao contrário de `mercado_pago_access_token_ciphertext`. `Marketplace::MercadoPagoOauth::Credentials` captura `public_key` da resposta do `/oauth/token`; um vendedor conectado **antes** desta fase não tem esse campo e precisa reconectar para que a opção de cartão apareça no checkout (`Seller#mercado_pago_card_payments_available?`) — PIX continua funcionando normalmente nesse meio-tempo.

O checkout agora tem uma etapa de escolha (`GET /orders/:id/payment/new` sem tentativa ainda) antes de autorizar: diferente do fluxo anterior, o `GET` não cria mais um `Payment` automaticamente. PIX autoriza assim que o cliente escolhe (`POST`, sem dado extra); cartão só autoriza depois que o Brick gera o token no navegador.

**Pendências antes de habilitar cartão em produção:**

* **CSP apertada, ainda não exercitada num browser** — os curingas `https://*.mercadopago.com`/`https://*.mlstatic.com` da primeira entrega foram substituídos pelos domínios exatos, cada um só na diretiva que o usa. A lista não saiu de documentação (a página OWASP dos Bricks não trata de CSP) e sim da leitura do próprio bundle servido em `https://sdk.mercadopago.com/js/v2`, onde os papéis estão explícitos no código: `cacheUrl` (`secure-fields.mercadopago.com`, o iframe dos campos — **frame-src apenas, nunca script-src**), `sourceUrl` (`api-static.mercadopago.com/secure-fields`), `assetsBaseUrl` (`http2.mlstatic.com/frontend-assets/op-cho-bricks`), as chamadas XHR em `api.mercadopago.com` (`/v1`, `/v2`, `/bricks`, `/op-pay/web/v1`, `/op-frontend-metrics/v1`) e a telemetria melidata em `api.mercadolibre.com/tracks`. Os domínios `-stg` existem no SDK só nos perfis `test1`/`test2` e ficaram de fora de propósito — se o Brick quebrar no sandbox, é o primeiro lugar a olhar. `spec/requests/security_headers_spec.rb` trava as invariantes (nenhum curinga, `script-src` com nonce e sem `unsafe-inline`, cada domínio na sua diretiva). **Exercitada num browser em 2026-09-12 e a lista de domínios estava certa** — nenhum bloqueio por domínio. O que apareceu foi outro tipo de bloqueio, de script *inline*, que curinga nenhum resolveria: ver o item do `deviceProfileCspNonce` abaixo. Se um dia o console acusar bloqueio por domínio, acrescente o faltante à diretiva específica — nunca volte ao curinga.
* **`style-src` usa `unsafe-inline` por necessidade do SDK** — o Brick injeta `<style>` em runtime (spinner de carregamento, botão de fechar, estilos do container) e esses blocos não carregam nonce, porque o SDK não aplica nonce nesses blocos (ele só aceita nonce para o script do device profile, via `deviceProfileCspNonce` — ver o item abaixo; para `<style>` não há opção equivalente). Nenhum curinga de domínio resolveria isso: para estilo inline o que vale é `unsafe-inline`, e o browser o ignora quando a diretiva também tem nonce — por isso `style-src` saiu de `content_security_policy_nonce_directives`. O afrouxamento vale ser reconhecido: qualquer estilo inline passa a ser aceito. O risco é contido (CSS injetado não executa script, `script-src` segue com nonce e sem `unsafe-inline`, e nenhuma view da aplicação tem `<style>` próprio); a alternativa seria hashear cada bloco do SDK, que muda a cada release deles e quebraria o checkout sem aviso.
* **Sandbox nunca testado** — mesma situação do PIX (ver abaixo): o adapter e os testes cobrem o contrato (stub HTTP), não a API real do Mercado Pago para cartão.
* **`script-src` exige `deviceProfileCspNonce` no SDK** — o Brick injeta em runtime um `<script>` inline com o widget antifraude (device profile, buscado em `/devices/widgets`). Sem nonce, a CSP o bloqueia e o Brick fica **preso no skeleton**, sem nunca renderizar os campos — observado em produção em 2026-09-12, com vendedor real. O SDK expõe a opção `deviceProfileCspNonce`, que ele aplica no script injetado (`e && (n.nonce = e)`) e valida como string sem espaços; `app/views/payments/new.html.erb` passa `content_security_policy_nonce` ao controller Stimulus, que o repassa ao construtor. **A CSP não foi afrouxada**: `unsafe-inline` em `script-src` desligaria a proteção contra XSS justamente na tela do cartão (e obrigaria a abrir mão do nonce, já que o browser ignora `unsafe-inline` quando há nonce na diretiva); hash `sha256` quebraria sem aviso, porque o widget vem de endpoint dinâmico; `strict-dynamic` autorizaria o SDK a carregar qualquer script. Consequência que vale registrar: enquanto durou o bloqueio, **o antifraude não rodava em nenhuma transação de cartão**.

* **Verificação visual do Brick parcialmente feita** — a tela de escolha e o fluxo PIX foram validados ponta a ponta via requisições HTTP diretas. Em 2026-09-12 o Brick foi exercitado num browser real pela primeira vez, o que rendeu dois defeitos invisíveis para as suítes (o botão fora do escopo do controller Stimulus e o bloqueio de CSP acima). Falta o pagamento com cartão de teste ponta a ponta, incluindo a conferência do split.

### Webhook

A notificação do Mercado Pago **não carrega o status de forma confiável**: ela avisa que o pagamento X mudou e espera que a aplicação consulte a API. Por isso `webhook_event` faz uma chamada de volta ao gateway. Sem isso, bastaria forjar um POST para marcar um pedido como pago.

A autenticidade vem de HMAC-SHA256 sobre um manifesto (`id` + `x-request-id` + `ts`), comparado de forma timing-safe — diferente do segredo simples do gateway fake.

O `event_id` combina pagamento e status (`mp-<id>-<status>`) porque o Mercado Pago notifica o mesmo pagamento a cada mudança; usar só o id faria a segunda notificação ser descartada como duplicata por `Payments::ProcessWebhook`.

O endpoint a configurar no painel é `POST /webhooks/payments`.

### O que ainda não foi verificado

O adapter e seus testes existem, mas **a integração nunca rodou contra o sandbox do Mercado Pago** — falta credencial. Os testes stubam HTTP e verificam o contrato do adapter (o que envia, o que devolve, o que recusa), não a API real. Antes de ligar `PAYMENT_GATEWAY=mercado_pago` em produção, é obrigatório um teste ponta a ponta no sandbox.

### Renovação e acompanhamento do PIX

As três lacunas identificadas antes do teste no sandbox foram fechadas:

1. `Payments::Authorize` reaproveita um pagamento `pending` somente enquanto o PIX ainda está válido. Ao abrir novamente a etapa de pagamento depois da expiração, a tentativa anterior vira `failed` e uma nova cobrança é criada. Isso não cancela o pedido sozinho — quem cancela é `Orders::CancelExpired` (ver abaixo).
2. Cada `Payment` possui sua própria `idempotency_key`. A tentativa é persistida no estado interno `processing` antes da chamada externa; se houver timeout ou queda depois que o Mercado Pago receber a requisição, o retry retoma o mesmo registro e a mesma chave. Uma tentativa posterior a um QR expirado recebe outra chave.
3. A página do PIX consulta periodicamente um endpoint somente de leitura, autenticado e escopado ao dono do pedido. O bloco de pagamento reflete `paid`/`failed` assim que o webhook atualizar o banco, sem criar cobranças durante o polling. Se o QR vencer com a página aberta, o polling para e a interface oferece uma nova tentativa.

### Cancelamento automático por PIX expirado

**Decisão de negócio**: um pedido `pending` cujo PIX expirou é cancelado automaticamente depois de 1 hora de tolerância (`Orders::CancelExpired::GRACE_PERIOD`) — não imediatamente, para dar chance de uma nova tentativa antes do cancelamento.

`CancelExpiredOrdersJob` roda a cada 15 minutos via Solid Queue (`config/recurring.yml`) e delega a `Orders::CancelExpired`. Um pedido é candidato quando está `pending`, tem um `Payment` `pending` cujo `expires_at` passou de mais de 1 hora, e nenhum `Payment` do pedido chegou a `authorized`/`paid`/`partially_refunded`/`refunded` — protege contra cancelar um pedido que na verdade já foi pago (ex: webhook atrasado).

Ao cancelar, o estoque debitado no checkout é devolvido (`Product#stock_quantity` ou `ProductVariant#stock_quantity`, dependendo se o item tem variante), exceto para produtos `made_to_order` (sem estoque físico). Peça única (`one_of_a_kind`) mantém a regra já existente de não voltar a `active` automaticamente depois de `sold_out` — devolver o `stock_quantity` não contorna isso, porque a transição de status não é disparada por este serviço.

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

## Avisos do pedido confirmado (fan-out)

Quando — e somente quando — um evento confirma o pedido, `Payments::ProcessWebhook` enfileira três jobs independentes:

| job | destinatário | conteúdo |
| --- | --- | --- |
| `SendOrderConfirmationJob` | cliente | itens com prazo de produção e personalizações, totais, endereço de entrega |
| `NotifySellerOfOrderJob` | artesão (o `User` do ateliê) | itens a produzir com SKU e personalizações, valores **com a comissão discriminada**, endereço de envio |
| `RecordOrderAnalyticsJob` | log estruturado | evento `order.confirmed` com valores e ids, pesquisável no Log Explorer |

Três decisões que sustentam isso:

**Um job por aviso, não um só.** Se o e-mail do cliente falhar, o artesão ainda é avisado e a venda ainda é registrada. Um job único faria a falha de um derrubar os outros (§49).

**A idempotência vem da máquina de estados, não de uma flag nova.** `ALLOWED_STATUS_TRANSITIONS` não permite `confirmed → confirmed`, e `apply_status!` devolve `true` apenas quando *aquele* evento foi o que confirmou. Um webhook repetido, um retry com `event_id` novo, ou a confirmação síncrona do cartão chegando junto do webhook — nenhum reenvia os avisos. Não foi preciso criar `confirmed_at` nem coluna de controle: a invariante já existia.

**O enfileiramento é fora da transação.** Solid Queue grava num banco separado (ver `CLAUDE.md`), então um job enfileirado dentro da transação pode ser lido por um worker antes do commit — e o job encontraria um pedido que ainda não existe para ele.

O disparo é único (`ProcessWebhook`) porque cartão e PIX convergem ali: a Fase 24 reaproveita esse serviço com um `event_id` sintético para a confirmação síncrona.

`NotifySellerOfOrderJob` recebe o `SellerOrder`, não o `Order`, de propósito: hoje há sempre um só (o checkout aceita um vendedor), mas quando o split 1:N for liberado o fan-out passa a enfileirar um job por vendedor sem reescrever o job. Ateliê sem usuário vinculado não recebe e-mail e isso não é erro — não há destinatário, e repetir não criaria um.

## Idempotência

Além dos webhooks, a criação do pagamento é idempotente por tentativa. Retries técnicos da mesma tentativa conservam a chave; uma tentativa comercialmente nova, necessária depois de recusa ou expiração, usa outra chave. O lock do pedido impede que requisições concorrentes criem registros de tentativa independentes.

## Logs

Nunca registrar em logs: senha, token de autenticação, número de cartão, CVV, ou qualquer credencial. Usar `Rails.application.config.filter_parameters` para garantir isso. Ver também `docs/security.md`.

## Marketplace

O vínculo do vendedor com o Mercado Pago foi introduzido na Fase 22 via OAuth Authorization Code com PKCE (S256) — a aplicação Marketplace exige PKCE nas configurações avançadas, e sua ausência produz `invalid_client` (HTTP 400) no `/oauth/token`, o mesmo erro de uma credencial errada. O vendedor precisa ter conta Mercado Pago com KYC nível 6, requisito confirmado manualmente pela plataforma porque a resposta OAuth pública não informa esse nível. A aplicação armazena somente o identificador do vendedor, datas e tokens cifrados; documentos permanecem no Mercado Pago. Para ativar o fluxo são necessárias `MERCADO_PAGO_MARKETPLACE_APP_ID`, `MERCADO_PAGO_MARKETPLACE_CLIENT_SECRET` e `MERCADO_PAGO_MARKETPLACE_REDIRECT_URI`.

`MERCADO_PAGO_MARKETPLACE_CLIENT_SECRET` **não** é o Access Token (nem o de teste, nem o de produção) — é o par `Client ID`/`Client Secret` que só aparece na tela "Credenciais de produção" da aplicação, mesmo para autenticar contra o sandbox (`client_id`/`client_secret` identificam a aplicação; `test_token=true` no corpo da requisição é o que sinaliza que o resultado deve ser uma conta de teste). Usar o Access Token no lugar do Client Secret também produz `invalid_client`.

O sandbox é opt-in por `MERCADO_PAGO_MARKETPLACE_SANDBOX=true`. Nesse modo, a troca do authorization code envia o parâmetro documentado `test_token=true` e o painel identifica explicitamente que a conta TESTUSER não permite aprovação nem vendas reais. A variável vem somente do ambiente, nunca da requisição do vendedor. Produção é o padrão seguro e não envia `test_token`. As credenciais da aplicação Marketplace de testes devem ficar separadas das produtivas.

O fluxo completo (autorização → callback → troca de token → conexão do `Seller`) já rodou ponta a ponta no sandbox com uma conta TESTUSER do tipo Vendedor, confirmando PKCE e o Client Secret corretos. A conexão resultante continua em produção (`Ateliê do Mercado Pago`, `live_mode: false`, 2026-09-06), ao lado de uma conexão real (`Ateliê da Ana`, `live_mode: true`). Nenhuma das duas tem `mercado_pago_public_key`, porque ambas são anteriores à Fase 24 — reconectar grava a chave e é o que falta para o cartão; o PIX não depende dela. Para conferir esse estado, consulte o `Seller` no banco de produção via `railway ssh` (`/admin/contas-de-teste-mercado-pago` é um cofre opcional de credenciais e estar vazio não significa ausência de conta de teste).

Na Fase 23, pagamentos passaram a suportar split entre vendedor e plataforma. `Payments::Authorize` usa o access token OAuth do vendedor e envia `application_fee` no PIX. A comissão é 15% do subtotal dos produtos após descontos, sem frete; a tarifa do Mercado Pago é registrada separadamente e suportada pelo vendedor. Reembolsos são operados apenas pelo admin da plataforma, usam chave de idempotência, preservam cada tentativa em `PaymentRefund` e revertem a comissão proporcionalmente sem erro acumulado de arredondamento. No primeiro lançamento, cada checkout tem um único vendedor/`SellerOrder` e usa o split público 1:1; multi-vendedor depende de habilitação comercial do split 1:N. Não são criados múltiplos PIX para uma compra nem repasses manuais a partir da conta da plataforma.

## Quando a criação da cobrança falha

Se a chamada ao gateway levanta, a tentativa **permanece `processing`** de propósito: a cobrança pode ter nascido do outro lado (um timeout não diz se a requisição chegou), e `Payments::Authorize#prepare_attempt` reusa esse registro para não gerar cobrança dupla — a mesma chave de idempotência vale para a próxima tentativa. `Payment#external_id` é obrigatório para qualquer status que não seja `processing`, então "falhou antes de existir cobrança" não tem outro estado onde caber.

O custo disso caía sobre o cliente: a tela mostrava "Preparando a cobrança. Aguarde alguns instantes." indefinidamente, e o polling seguia consultando um status que nunca mudaria. Aconteceu em produção em 2026-09-08. `Payment#stalled?` (`PROCESSING_STALE_AFTER`, 2 min — generoso perto dos timeouts de 5s/15s do gateway) separa "ainda pode chegar" de "não vem mais": passado o limite, a tela admite a falha, oferece "Tentar novamente" e para de consultar. O registro continua `processing` no banco, então a proteção contra cobrança dupla permanece intacta.

## Diagnóstico de falhas do gateway

`RequestFailed` carrega o **código de erro** do Mercado Pago (`"...respondeu 500 em /v1/payments (user_allowed_only_in_test)"`), e `payment.mercado_pago_gateway_http_error` registra `error`/`message`/`cause` do corpo. O corpo completo continua fora de ambos, porque pode ecoar dados do pagamento (§43) — mas só o status HTTP não basta: em 2026-09-08 um "respondeu 500" sem código custou uma investigação inteira.

**`user_allowed_only_in_test` não é sobre o pagador.** O Mercado Pago devolve esse erro quando o meio de pagamento pedido **não está habilitado na conta do vendedor**. Confirmado consultando `GET /v1/payment_methods` com o token do artesão: a conta TESTUSER de sandbox lista 19 métodos (cartão de crédito, débito, pré-pago, boleto, saldo) e **PIX não está entre eles**. Antes de investigar credenciais ou pagador, consulte `/v1/payment_methods`: é uma chamada de leitura e responde direto.

**PIX não é testável no sandbox — e a explicação registrada aqui antes estava errada.** A conclusão anterior era que faltava cadastrar uma chave PIX na conta TESTUSER, e que isso se resolveria no painel do Mercado Pago. Não se resolve: a documentação oficial afirma que **pagamentos com PIX não podem ser feitos com credenciais de teste**, e a própria página de teste de integração recomenda escolher outro meio de pagamento para validar o QR Code nessa fase (ver "Posso pagar com Pix em ambiente de teste?" na ajuda e a seção de teste de integração de PIX na doc de desenvolvedores). A observação de `/v1/payment_methods` continua correta e é justamente o que se espera nesse cenário — PIX não aparece porque não existe para credencial de teste, não porque falte configuração. Consequências: **cartão** é o meio a usar no sandbox, com os cartões de teste do provedor; e **PIX só se valida em produção**, com conta real e cobrança de valor baixo — decisão de negócio, por envolver dinheiro real. Erro de método registrado (terceira ocorrência do mesmo padrão): a observação era boa, a causa foi inferida dela sem consultar a documentação.

## Relação com o pedido

* Pagamento aprovado deve confirmar o pedido (`Order` transita para `confirmed` — ver `docs/checkout.md` e `docs/domain.md`).
* Pagamento recusado não deve confirmar o pedido nem debitar estoque de forma definitiva.

`TODO — DECISION REQUIRED`: a política exata de quanto tempo um pedido `pending` aguarda confirmação de pagamento antes de liberar o estoque reservado (se houver reserva) não está definida — depende da modelagem de estoque escolhida na Fase 8 e deve ser uma decisão de negócio.
