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

A tokenização acontece no navegador via **Checkout Bricks** (Card Payment Brick, `sdk.mercadopago.com/js/v2`) — nenhum dado de cartão trafega pelo backend, só o token gerado pelo Brick. Isso exige a **Public Key** do vendedor (`Seller#mercado_pago_public_key`), diferente do Access Token: é pública por design e não é cifrada no banco, ao contrário de `mercado_pago_access_token_ciphertext`. `Marketplace::MercadoPagoOauth::Credentials` captura `public_key` da resposta do `/oauth/token`; um vendedor conectado **antes** desta fase não tem esse campo e precisa reconectar para que a opção de cartão apareça no checkout (`Seller#mercado_pago_card_payments_available?`) — PIX continua funcionando normalmente nesse meio-tempo. Em produção isso já foi feito para o vendedor de sandbox: ver "Estado das contas em produção" abaixo.

O checkout agora tem uma etapa de escolha (`GET /orders/:id/payment/new` sem tentativa ainda) antes de autorizar: diferente do fluxo anterior, o `GET` não cria mais um `Payment` automaticamente. PIX autoriza assim que o cliente escolhe (`POST`, sem dado extra); cartão só autoriza depois que o Brick gera o token no navegador.

**Pendências antes de habilitar cartão em produção:**

* **CSP apertada, ainda não exercitada num browser** — os curingas `https://*.mercadopago.com`/`https://*.mlstatic.com` da primeira entrega foram substituídos pelos domínios exatos, cada um só na diretiva que o usa. A lista não saiu de documentação (a página OWASP dos Bricks não trata de CSP) e sim da leitura do próprio bundle servido em `https://sdk.mercadopago.com/js/v2`, onde os papéis estão explícitos no código: `cacheUrl` (`secure-fields.mercadopago.com`, o iframe dos campos — **frame-src apenas, nunca script-src**), `sourceUrl` (`api-static.mercadopago.com/secure-fields`), `assetsBaseUrl` (`http2.mlstatic.com/frontend-assets/op-cho-bricks`), as chamadas XHR em `api.mercadopago.com` (`/v1`, `/v2`, `/bricks`, `/op-pay/web/v1`, `/op-frontend-metrics/v1`) e a telemetria melidata em `api.mercadolibre.com/tracks`. Os domínios `-stg` existem no SDK só nos perfis `test1`/`test2` e ficaram de fora de propósito — se o Brick quebrar no sandbox, é o primeiro lugar a olhar. `spec/requests/security_headers_spec.rb` trava as invariantes (nenhum curinga, `script-src` com nonce e sem `unsafe-inline`, cada domínio na sua diretiva). **Exercitada num browser em 2026-09-12 e a lista de domínios estava certa** — nenhum bloqueio por domínio. O que apareceu foi outro tipo de bloqueio, de script *inline*, que curinga nenhum resolveria: ver o item do `deviceProfileCspNonce` abaixo. Se um dia o console acusar bloqueio por domínio, acrescente o faltante à diretiva específica — nunca volte ao curinga.
* **`style-src` usa `unsafe-inline` por necessidade do SDK** — o Brick injeta `<style>` em runtime (spinner de carregamento, botão de fechar, estilos do container) e esses blocos não carregam nonce, porque o SDK não aplica nonce nesses blocos (ele só aceita nonce para o script do device profile, via `deviceProfileCspNonce` — ver o item abaixo; para `<style>` não há opção equivalente). Nenhum curinga de domínio resolveria isso: para estilo inline o que vale é `unsafe-inline`, e o browser o ignora quando a diretiva também tem nonce — por isso `style-src` saiu de `content_security_policy_nonce_directives`. O afrouxamento vale ser reconhecido: qualquer estilo inline passa a ser aceito. O risco é contido (CSS injetado não executa script, `script-src` segue com nonce e sem `unsafe-inline`, e nenhuma view da aplicação tem `<style>` próprio); a alternativa seria hashear cada bloco do SDK, que muda a cada release deles e quebraria o checkout sem aviso.
* **Sandbox nunca testado** — mesma situação do PIX (ver abaixo): o adapter e os testes cobrem o contrato (stub HTTP), não a API real do Mercado Pago para cartão.
* **`script-src` exige `deviceProfileCspNonce` no SDK** — o Brick injeta em runtime um `<script>` inline com o widget antifraude (device profile, buscado em `/devices/widgets`). Sem nonce, a CSP o bloqueia e o Brick fica **preso no skeleton**, sem nunca renderizar os campos — observado em produção em 2026-09-12, com vendedor real. O SDK expõe a opção `deviceProfileCspNonce`, que ele aplica no script injetado (`e && (n.nonce = e)`) e valida como string sem espaços; `app/views/payments/new.html.erb` passa `content_security_policy_nonce` ao controller Stimulus, que o repassa ao construtor. **A CSP não foi afrouxada**: `unsafe-inline` em `script-src` desligaria a proteção contra XSS justamente na tela do cartão (e obrigaria a abrir mão do nonce, já que o browser ignora `unsafe-inline` quando há nonce na diretiva); hash `sha256` quebraria sem aviso, porque o widget vem de endpoint dinâmico; `strict-dynamic` autorizaria o SDK a carregar qualquer script. Consequência que vale registrar: enquanto durou o bloqueio, **o antifraude não rodava em nenhuma transação de cartão**.

* **Verificação visual do Brick FEITA em 2026-09-12; o bloqueio restante é do provedor** — o Brick renderiza os campos, tokeniza o cartão no navegador (`card_token` chega ao backend já filtrado, §43) e o backend chama `/v1/payments`. A cadeia da EloShop está validada ponta a ponta. O que falha é a criação da cobrança: **HTTP 500 com `error: internal_error` e `cause: []`**, resposta genérica que não indica campo inválido nem credencial. Reproduzido com o cartão de teste oficial (`5480 8328 0103 3311`, titular `APRO`, CPF `12345678909`, qualquer validade futura e CVV de 3 dígitos) e 1 parcela, e idêntico ao que o PIX levou em 2026-09-09 na mesma conta de teste (`143360137`) — dois meios de pagamento, duas datas, mesmo sintoma. **Terceira reprodução em 2026-09-13, 20:07:42 UTC** (pedido #37, `Ateliê do Mercado Pago`): `error=null`, `cause=[]`, confirmando que o corpo é JSON válido com campos vazios — não é o caso de corpo ilegível que o log de 2026-09-13 (`9aa3157`) passou a diagnosticar; é o provedor respondendo formato correto e conteúdo vazio mesmo. Não deduzir a causa a partir disso: `cause: []` é a ausência da informação que a confirmaria. O caminho é chamado com o Mercado Pago. **O split e a comissão de 15% seguem sem validação ponta a ponta**, porque dependem de um pagamento que conclua.

  **Chamado aberto com o suporte do Mercado Pago (2026-09-14); `application_fee` descartado como causa.** O suporte sugeriu isolar se `application_fee` provoca o 500, com um teste A/B (mesma chamada, com e sem o campo). `lib/tasks/mercado_pago_diagnostics.rake` (`mercado_pago:diagnose_application_fee[order_id]`) automatiza esse teste contra o gateway real. Rodado em produção às 2026-09-14 07:50 UTC contra o pedido #38 (`Ateliê do Mercado Pago`, mesma conta de teste `143360137`): **os dois casos falharam de forma idêntica**, com e sem `application_fee_cents`, ambos HTTP 500 `internal_server_error`. `application_fee` está descartado como causa — o 500 independe do valor desse campo.

  A mesma execução capturou pela primeira vez o campo `message` do corpo do erro, que nas ocorrências anteriores vinha vazio: **`"http is unavailable for request create_ti"`**. É a primeira pista concreta desde que o bloqueio foi aberto — sugere indisponibilidade interna de um serviço do lado do Mercado Pago (o sufixo `create_ti` nomeia a operação que falhou), não um problema de payload, credencial ou conta.

  **Formatação/estrutura do request também descartada (2026-09-14 08:01 UTC).** O suporte apontou duas direções para a causa: (a) algo de formatação/estrutura do request que passa validação e explode internamente, ou (b) intermitência/timeout do lado deles. Revisando o payload contra o exemplo oficial da documentação, duas diferenças concretas sustentavam (a): `transaction_amount`/`application_fee` vão como `Float` (`(cents / 100.0).round(2)`, não `Integer` como no exemplo oficial), e `description` carrega um em-dash (`—`, U+2014, não-ASCII) nos dois caminhos de pagamento. `mercado_pago:diagnose_request_shape[order_id]` isolou as duas contra o sandbox real, com três chamadas HTTP diretas (fora de `Gateways::MercadoPago`, para não misturar sonda de diagnóstico com código de produção): com/sem em-dash no `description`, e `transaction_amount` como `Integer` sem `description`. **Os três casos falharam de forma idêntica**, mesma mensagem `"http is unavailable for request create_ti"`. Com o teste de `application_fee` anterior, são cinco variações de payload testadas — todas com o mesmo sintoma. Isso descarta (a): a causa não está em nada que a EloShop envia.

  **Configuração do lado da EloShop também auditada e descartada (2026-09-14 08:0x UTC), direto no `Seller#5`.** Todas as variáveis de ambiente (`MERCADO_PAGO_MARKETPLACE_APP_ID/CLIENT_SECRET/REDIRECT_URI/SANDBOX`, `MERCADO_PAGO_WEBHOOK_SECRET`, `MERCADO_PAGO_TEST_PAYER_EMAIL`, `PAYMENT_GATEWAY`) presentes e com os valores esperados (`PAYMENT_GATEWAY=mercado_pago`, sandbox ligado). O access token do vendedor (`Marketplace::MercadoPagoAccessToken`) tem prefixo `TEST-`, confirmando que a troca OAuth com `test_token: true` produziu um token de sandbox de verdade, não `APP_USR` (produção). O mesmo token autentica normalmente: `GET /users/me` responde `200` (`site_id: MLB`, correto para conta brasileira), e **`GET /v1/payments/search` também responde `200`** — mesma API de pagamentos, mesmo token, mesmo escopo, sem erro. **Só a operação de criação (`POST /v1/payments`, o `create_ti` da mensagem) falha**, e falha igual em qualquer payload testado. Se fosse token, permissão ou conta mal configurada, a leitura em `/v1/payments/search` teria falhado do mesmo jeito — não falhou. Isolado: não é configuração da EloShop. Reportado de volta ao suporte; aguardando retorno sobre o que `create_ti` significa do lado deles.

  Nota lateral apurada durante o diagnóstico, não a causa do 500: `Seller#5` (`Ateliê do Mercado Pago`, `mercado_pago_user_id=143360137`) tem `mercado_pago_test_account: false` gravado no banco, apesar de ser a conta de teste usada em toda esta investigação. `mercado_pago_live_mode: false` confere com sandbox. `test_account` é decidido consultando a tag `test_user` em `/users/me` no momento da conexão (`Marketplace::MercadoPagoOauth#test_account?`) — um `false` gravado (em vez do `nil` que o código usa para "não foi possível confirmar") significa que a consulta respondeu e a tag não estava presente naquele momento, não uma falha de leitura. Não investigado a fundo; mencionado aqui para não confundir uma leitura futura de `Seller#mercado_pago_test_account` com o estado real da conta.

  **O sintoma mudou de 500 `create_ti` para 403 `Payer email forbidden` entre 08:0x e 08:40 UTC de 2026-09-14, sem nenhuma mudança do lado da EloShop.** O suporte pediu `X-Request-Id`, corpo completo mascarado e resposta JSON completa de uma tentativa que falhe — `mercado_pago:diagnose_capture_request_id[order_id]` (nova task) foi criada só para isso, sem alterar `Gateways::MercadoPago`. As três execuções seguintes contra o pedido #38, todas em produção, devolveram consistentemente `HTTP 403`, `error: "forbidden"`, `message: "Payer email forbidden"`, `cause: [{ code: 4390, description: "Payer email forbidden" }]` — não mais o 500 anterior:

  | Horário (UTC) | X-Request-Id |
  | --- | --- |
  | 08:32:25 | `c3147975-af1a-4893-b884-17984a89e39f` |
  | 08:40:35 | `f8556cf5-8ef1-4148-8234-f90d21f522f8` |
  | 08:41:00 | `00d28771-a877-4f89-9768-a81e9adbfcc0` |

  O `payer.email` enviado é `MERCADO_PAGO_TEST_PAYER_EMAIL`, confirmado como o mesmo comprador de teste já existente (`TESTUSER6506400863910076309`, criado em 2026-09-06, status `active`) via `mcp__mercadopago__create_test_user` — a API retornou "already exists" com esse nickname, e o sufixo/comprimento do e-mail configurado na Railway batem com ele. Não é e-mail de credencial errada nem de aplicação diferente.

  Também mudou desde a última verificação (`docs/payments.md`, "PIX não é testável no sandbox" abaixo): `GET /v1/payment_methods` agora lista **20 métodos** e **PIX está presente** — antes eram 19, sem PIX. Não sabemos se essa mudança e o novo 403 têm a mesma causa do lado do Mercado Pago, mas ambas apareceram na mesma janela e nenhuma foi provocada por uma mudança de configuração ou deploy da EloShop (nenhum deploy entre as duas leituras alterou `Gateways::MercadoPago`, `PAYMENT_GATEWAY` ou as variáveis do vendedor). Reportado ao suporte com os três `X-Request-Id` acima; aguardando retorno.

  **Resposta do suporte (chamado WCS-50393, 2026-09-14): 403/4390 é bloqueio de segurança/permissão, hipótese principal é "pagar a si mesmo".** O suporte confirmou que o 403 com `code: 4390` já não é erro interno — é bloqueio por regra de segurança, e um dos cenários documentados para esse tipo de 403 é comprador e vendedor resolverem para a mesma pessoa/conta. Eles pediram para confirmar (1) que o `payer.email` enviado é o e-mail completo, sem máscara ou transformação, e (2) se o comprador de teste usado colide com o vendedor conectado.

  **Hipótese de colisão testada com os IDs disponíveis, sem confirmação nem descarte.** O comprador de teste (`TESTUSER6506400863910076309`) tem `User ID 3671163030` (via `mcp__mercadopago__create_test_user`); o vendedor conectado (`Seller#5`) tem `mercado_pago_user_id 143360137`. São IDs numéricos diferentes — descarta colisão literal por `user_id`. Achado na documentação oficial um erro nomeado da mesma família, `UserIdEqualsCollectorId` ("The buyer and seller cannot be the same Mercado Pago user"), mas documentado só para a Agreements API do Wallet Connect, não para `/v1/payments` — confirma que a regra de negócio existe no Mercado Pago e generaliza entre produtos, não que é a causa aqui. Em aberto: se a checagem por trás do `code: 4390` compara por CPF/documento (e não só por `user_id`), comprador e vendedor de teste poderiam colidir por trás de contas com IDs diferentes — não há como confirmar isso sem acesso às credenciais do comprador de teste ou resposta do suporte.

  **Pista descartada no caminho: app_id do comprador de teste não indica mistura de contas.** `create_test_user` devolveu o comprador existente sob o app_id `6401332976229887`, que não aparece em `application_list` desta conta (só lista `EloShopOficial` e `EloShop Marketplace Oficial`) — parecia sugerir um usuário de teste de outra aplicação/conta. Descartado: `get_credentials` para `EloShopOficial` mostra que cada aplicação recebe seu próprio "seller app" auto-gerado pelo Mercado Pago ao provisionar teste (`seller app 529069968586172` para `EloShopOficial`, diferente do app real) — é como o provedor nomeia esse ID interno, não evidência de conta cruzada. Erro de método a não repetir: um ID de aplicação desconhecido não é, por si, sinal de mistura de ambiente.

  Atualizado de volta ao suporte com a análise acima; próximo passo é a resposta deles sobre se `code: 4390` verifica identidade por `user_id` ou por documento.

  **Causa raiz encontrada (2026-09-14): `Seller#5` estava conectado com uma conta pessoal real, não com TESTUSER.** `GET /users/me` com o token do vendedor devolveu `tags: ["normal", "messages_as_seller", "user_product_seller"]` — sem `test_user` — e nome/e-mail pessoais reais. `mercado_pago_test_account: false`, gravado desde a conexão original, estava correto o tempo todo; a investigação presumiu tratar-se de conta de teste porque foi usada como tal desde a Fase 22. Reconectado com um TESTUSER seller já existente e nunca usado (`3656967034`, `TESTUSER650137251329862929`, criado em 2026-09-01) — `approve!(kyc_level_6_confirmed: true)` aceitou porque `MERCADO_PAGO_MARKETPLACE_SANDBOX=true` está ligado em produção (`approvable_account?` libera conta de teste só nesse caso).

  **Tentativa de isolar por e-mail genérico, revertida: trocou um erro pelo outro, não eliminou o 403.** Com o vendedor já corrigido (TESTUSER), o 403 continuou em `/orders/40/payment` pelo fluxo real. Testado à parte, em chamada direta a `/v1/payments` (mesmo token do vendedor TESTUSER, variando só `payer.email`): com `MERCADO_PAGO_TEST_PAYER_EMAIL` (o TESTUSER buyer `TESTUSER6506400863910076309`) → `403 Payer email forbidden`; com um e-mail comum (`comprador.teste.eloshop@gmail.com`) → sem 403 nessa chamada isolada, só o já conhecido `user_allowed_only_in_test` do PIX. Isso parecia bater com a documentação de "Realizar compra teste" (Checkout Transparente/Bricks não exigiria TESTUSER como comprador) — mas ao aplicar a mesma troca em produção e testar pelo fluxo real de cartão, o resultado foi outro erro, não a ausência de erro: `400 bad_request`, `"Invalid test user email"`. A variável foi revertida de volta ao TESTUSER original; o código (`payer_email_for`) nunca foi alterado — só o comentário chegou a ser editado e revertido junto. Erro de método: o teste isolado (PIX, chamada direta) não é o mesmo caminho do teste real (cartão, via `PaymentsController`), e um resultado limpo no primeiro não confirma o segundo.

  **Com vendedor TESTUSER e comprador TESTUSER — a combinação nunca testada antes — o 403 persiste.** Teste pelo fluxo real (`POST /orders/40/payment`, cartão), 2026-09-14 14:23:46 UTC: vendedor `TESTUSER650137251329862929` (`mercado_pago_user_id 3656967034`, `mercado_pago_test_account: true`, confirmado no banco no momento exato da falha) e comprador `TESTUSER6506400863910076309` (`MERCADO_PAGO_TEST_PAYER_EMAIL`, valor original). Resultado: `403`, `error: forbidden`, `cause: [{code: 4390, description: "Payer email forbidden"}]`, `X-Request-Id: dd8bb14f-c68c-4bdf-8a16-a0a2649eb745`. Isso descarta a leitura de que bastaria os dois lados serem contas de teste — já eram, e o erro persistiu idêntico. Os dois TESTUSER têm datas de criação diferentes (vendedor 2026-09-01, comprador 2026-09-06) e foram obtidos em chamadas separadas de `create_test_user`; se precisam ser um par gerado junto para o Mercado Pago aceitar a combinação é hipótese não confirmada, repassada ao suporte junto com o `X-Request-Id` acima.

  **Duas causas, uma investigação, nenhuma fechada**: o 500 `create_ti` original (`cause: []`, opaco) nunca teve explicação própria — o suporte confirmou que o comportamento mudou para 403 antes de uma causa ser isolada. A troca de vendedor (conta pessoal → TESTUSER) era a hipótese mais forte para o 403 e não resolveu sozinha. **Estado real: nenhuma configuração testada até agora — vendedor real, vendedor TESTUSER, comprador TESTUSER, comprador comum — eliminou o 403 no fluxo real de cartão.** Não deduzir causa a partir disso; é o próprio padrão que esta investigação já cometeu quatro vezes antes. Próximo passo é a resposta do suporte.

  **Resposta do suporte (2026-09-15, ticket WCS-50393): pediu comprador de teste novo e distinto, e dados de correlação do 500 original.** O suporte pediu (a) criar um comprador de teste novo, do Brasil, na mesma aplicação, distinto do vendedor; (b) confirmar que o token TEST- foi gerado autorizando exatamente a conta vendedora `143360137`, com `test_token=true`; (c) IDs de integrador/vendedor/comprador usados; (d) para o 500 original, `X-Request-Id`, data/hora UTC, payload e headers completos mascarados.

  **(a) Comprador novo tentado via `mcp__mercadopago__create_test_user` (site `MLB`, profile `buyer`) — a API devolveu o mesmo comprador de sempre, não um novo.** Resposta: `"Test user already exists"`, `User ID 3671163030`, `TESTUSER6506400863910076309` (o mesmo já usado em toda a investigação). O provedor associa TESTUSER a par (conta de desenvolvedor, site, perfil), não por chamada — não há parâmetro que force um segundo buyer distinto para a mesma conta/site/perfil. Repassado ao suporte como resposta, não como algo resolvido do lado da EloShop.

  **(b) O vendedor `143360137` citado pelo suporte não é mais o vendedor ativo nos testes.** Esse ID é o da conta pessoal real identificada como causa raiz em 2026-09-14 (ver acima) — já foi desconectado e substituído por um TESTUSER seller (`3656967034`, `TESTUSER650137251329862929`, `test_token: true` confirmado via `test_account: true` no banco). Os testes mais recentes (incluindo o item abaixo, "vendedor TESTUSER e comprador TESTUSER") já usam `3656967034`, não `143360137`. Isso precisa ficar explícito na resposta ao suporte para não investigarem o vendedor errado.

  **(c) IDs consolidados para a resposta:** integrador — aplicação `3632658122100985` (`EloShop Marketplace Oficial`, a de produção com split); vendedor de teste — `3656967034` (`TESTUSER650137251329862929`); comprador de teste — `3671163030` (`TESTUSER6506400863910076309`).

  **(d) Não há X-Request-Id do 500 original — só do 403 que o sucedeu.** O 500 `create_ti` parou de ser reprodutível antes de uma captura dedicada existir (`diagnose_capture_request_id` só foi criada depois, para o 403). Os únicos `X-Request-Id` registrados nesta investigação são os três do 403 (tabela acima) e o de `dd8bb14f-c68c-4bdf-8a16-a0a2649eb745` (item "vendedor TESTUSER e comprador TESTUSER"). Não inventar um X-Request-Id do 500 — a resposta ao suporte deve dizer que o sintoma mudou antes da captura pedida existir, e oferecer os dados do 403 em seu lugar.

  **Segunda resposta do suporte (2026-09-17, mesmo ticket WCS-50393): o fluxo suportado dispensa TESTUSER dos dois lados — o oposto do que a investigação vinha configurando.** O suporte descreveu o fluxo esperado para testar split de marketplace: (1) vincular por OAuth a conta real do integrador à **conta vendedora real**, gerando o authorization code; (2) na troca do code, informar `test=true` para gerar as **credenciais de teste dessa vinculação**; (3) usar essas credenciais no `POST /v1/payments`, com `application_fee` quando aplicável. E fechou com a frase que muda a direção: **"Nesse fluxo, não é necessário criar ou utilizar usuários de teste."**

  Conferido contra o estado real em 2026-09-17 (`railway ssh`, `Seller.find_each`), dos três passos **dois já estão certos e os dois desvios são exatamente os TESTUSER**: o `test_token: "true"` na troca do code já é o comportamento do código em sandbox (`Marketplace::MercadoPagoOauth#exchange`, `app/services/marketplace/mercado_pago_oauth.rb:71`) e o `application_fee` já é enviado por `Gateways::MercadoPago`; mas o vendedor conectado hoje no `Seller#5` é o TESTUSER `3656967034` (`test_account: true`), não uma conta real, e o comprador é o TESTUSER `3671163030` via `MERCADO_PAGO_TEST_PAYER_EMAIL`. Ou seja: a credencial `TEST-` **já é** o ambiente de teste, e sobrepor contas TESTUSER a ela é o que está fora do fluxo suportado. Os dois desvios foram introduzidos deliberadamente por esta investigação, como hipóteses para o 403 — nenhum veio da documentação.

  **Isso reconcilia o resultado contraditório de 2026-09-14** (item "Tentativa de isolar por e-mail genérico"): naquele teste, comprador com e-mail comum **eliminou** o `403 Payer email forbidden` na chamada direta, e só virou `400 "Invalid test user email"` ao ser aplicado no fluxo real contra o vendedor TESTUSER. Sob a leitura do suporte os dois resultados deixam de se contradizer — comprador comum é o caminho certo, e o `400` é o vendedor TESTUSER recusando um comprador que não é TESTUSER. **É leitura, não causa confirmada**: nada foi testado ainda nessa configuração.

  **A configuração que o suporte descreve nunca foi testada**, porque é o inverso de tudo que foi tentado até aqui: vendedor **conta real** (`143360137`, desconectado em 2026-09-14 justamente por ser suspeito de causa raiz), token `TEST-` por `test_token=true`, comprador com **e-mail comum**. Dois riscos antes de executar: reconectar `143360137` desfaz a troca de 2026-09-14 e o `Seller#5` fica sem `mercado_pago_public_key` (cartão indisponível nesse vendedor) até a reconexão concluir; e a hipótese "pagar a si mesmo" do 4390 volta a valer se a conta que integra e a conta vendedora forem a mesma — o comprador precisa ser e-mail comum **de terceiro**, e o suporte não esclareceu se "sua conta real" e "a conta vendedora real" podem coincidir. Se coincidirem, o teste exige uma segunda conta real de vendedor.

* **Cinco defeitos achados no dia da verificação visual**, nenhum detectável pelas suítes, que passavam verdes em todos: botão fora do escopo do controller Stimulus (#76); `<script>` inline do antifraude bloqueado pela CSP, resolvido com `deviceProfileCspNonce` (#77); `onReady` ausente, que fazia `cardPayment.js` recusar inicializar (#78); `secure-fields` faltando no `connect-src` (#79); e o "Tentar novamente" apontando para a própria tela de falha, beco sem saída fatal para cartão porque o token do Brick é de uso único (#80). Request spec vê o elemento no HTML e passa; as specs de CSP afirmam que o cabeçalho está bem formado, nunca que o SDK funciona sob ele.

**Cartão salvo não existe e não está planejado para esta fase.** O cliente informa o cartão a cada compra; nada é persistido além de `card_brand`/`card_last_four` no `Payment`, para exibição. O ADR 006 (`docs/decisions/006-saved-cards.md`) registra o desenho e o motivo estrutural de a funcionalidade não ser trivial aqui: o cofre de cartões do Mercado Pago pertence à conta que cobrou, e quem cobra é o artesão — um cartão salvo seria escopado ao par (cliente, vendedor), nunca uma carteira única da EloShop. Está `Proposed`, com cinco decisões de negócio pendentes.

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

O fluxo completo (autorização → callback → troca de token → conexão do `Seller`) já rodou ponta a ponta no sandbox com uma conta TESTUSER do tipo Vendedor, confirmando PKCE e o Client Secret corretos. A conexão resultante continua em produção (`Ateliê do Mercado Pago`, `live_mode: false`, 2026-09-06), ao lado de uma conexão real (`Ateliê da Ana`, `live_mode: true`).

#### Estado das contas em produção (conferido em 2026-09-13)

Cinco `Seller` existem no banco de produção, e **apenas um oferece cartão**:

| Vendedor | `live_mode` | Public Key | Cartão no checkout |
| --- | --- | --- | --- |
| `EloShop` | `true` | — | não |
| `Ateliê da Ana` | `true` | — | não |
| `Rock Store` | `false` | — | não |
| `House of Horror` | `false` | — | não |
| `Ateliê do Mercado Pago` | `false` | **sim** | **sim** |

O `Ateliê do Mercado Pago` reconectou em 2026-09-12 e gravou a `mercado_pago_public_key` — é por isso que a verificação visual do Brick daquele dia foi possível, e **nenhuma reconexão é necessária para testar cartão hoje**. `Rock Store` e `House of Horror` não constam do restante desta documentação e têm origem não apurada.

Este estado vive no banco de produção e muda por fora do repositório: depois de qualquer conexão ou reconexão de vendedor, confira o `Seller` via `railway ssh` em vez de confiar nesta tabela (`/admin/contas-de-teste-mercado-pago` é um cofre opcional de credenciais e estar vazio não significa ausência de conta de teste).

Na Fase 23, pagamentos passaram a suportar split entre vendedor e plataforma. `Payments::Authorize` usa o access token OAuth do vendedor e envia `application_fee` no PIX. A comissão é 15% do subtotal dos produtos após descontos, sem frete; a tarifa do Mercado Pago é registrada separadamente e suportada pelo vendedor. Reembolsos são operados apenas pelo admin da plataforma, usam chave de idempotência, preservam cada tentativa em `PaymentRefund` e revertem a comissão proporcionalmente sem erro acumulado de arredondamento. No primeiro lançamento, cada checkout tem um único vendedor/`SellerOrder` e usa o split público 1:1; multi-vendedor depende de habilitação comercial do split 1:N. Não são criados múltiplos PIX para uma compra nem repasses manuais a partir da conta da plataforma.

## Conciliação financeira no Admin

`/admin/financials` possui uma conciliação de leitura do relatório oficial de vendas do marketplace. A atualização é manual: o Admin não chama o provedor ao abrir a página. `Marketplace::MercadoPagoSalesReport` lista os `statements` existentes, baixa o demonstrativo mais recente em CSV e mantém o resultado no Solid Cache por 24 horas. Nenhuma estrutura, agenda ou statement é criado pela EloShop — essas operações alteram recursos no Mercado Pago e continuam sendo configuradas no painel/API do provedor.

O relatório é autenticado com `MERCADO_PAGO_MARKETPLACE_ACCESS_TOKEN`, que deve conter o **Access Token de produção da aplicação Marketplace**. Essa credencial é diferente de `MERCADO_PAGO_MARKETPLACE_CLIENT_SECRET` e dos tokens OAuth dos artesãos. Ela só existe no backend, nunca é escrita em cache, log ou HTML. Sem a variável, a página continua mostrando os valores locais e explica que a fonte oficial ainda não está configurada.

A conciliação cruza `PAYMENT` do relatório com `Payment#external_id` e, como fallback, `EXTERNAL_REFERENCE` com o id do pedido. A tabela mostra venda, artesão, valor, comissão do marketplace, tarifa do Mercado Pago e líquido recebido. Registros sem correspondência local também aparecem, identificados pelo vendedor informado pelo próprio relatório; pagamentos locais ainda ausentes do demonstrativo ficam marcados como “Somente EloShop”.

O Sales Report não contém a data de liberação do dinheiro. Durante a atualização manual, a aplicação consulta `GET /v1/payments/:id` com o token OAuth do respectivo artesão e lê `money_release_date`; no máximo 50 pagamentos são enriquecidos por atualização para limitar latência e chamadas ao provedor. Relatório e datas ficam em cache por 24 horas. A tela distingue explicitamente dados conciliados dos dados locais e não afirma que um valor local já foi confirmado pelo Mercado Pago.

## Quando a criação da cobrança falha

Se a chamada ao gateway levanta, a tentativa **permanece `processing`** de propósito: a cobrança pode ter nascido do outro lado (um timeout não diz se a requisição chegou), e `Payments::Authorize#prepare_attempt` reusa esse registro para não gerar cobrança dupla — a mesma chave de idempotência vale para a próxima tentativa. `Payment#external_id` é obrigatório para qualquer status que não seja `processing`, então "falhou antes de existir cobrança" não tem outro estado onde caber.

O custo disso caía sobre o cliente: a tela mostrava "Preparando a cobrança. Aguarde alguns instantes." indefinidamente, e o polling seguia consultando um status que nunca mudaria. Aconteceu em produção em 2026-09-08. `Payment#stalled?` (`PROCESSING_STALE_AFTER`, 2 min — generoso perto dos timeouts de 5s/15s do gateway) separa "ainda pode chegar" de "não vem mais": passado o limite, a tela admite a falha, oferece "Tentar novamente" e para de consultar. O registro continua `processing` no banco, então a proteção contra cobrança dupla permanece intacta.

## Diagnóstico de falhas do gateway

`RequestFailed` carrega o **código de erro** do Mercado Pago (`"...respondeu 500 em /v1/payments (user_allowed_only_in_test)"`), e `payment.mercado_pago_gateway_http_error` registra `error`/`message`/`cause` do corpo. O corpo completo continua fora de ambos, porque pode ecoar dados do pagamento (§43) — mas só o status HTTP não basta: em 2026-09-08 um "respondeu 500" sem código custou uma investigação inteira.

**Quando o corpo não é JSON, o evento identifica a camada que respondeu** (desde 2026-09-13). Antes disso o `rescue` devolvia `nil` e **nenhum evento era emitido**: a falha não deixava registro nenhum. A lacuna era a mesma que o Melhor Envio tinha até o PR #84, onde custou um acesso por `railway ssh` para descobrir que um 403 era `E-WAF-0003`, página de WAF servida pelo load balancer antes da API. Aqui o risco é idêntico: um 500 opaco de `/v1/payments` não distingue "o Mercado Pago recusou" de "a requisição nem chegou ao Mercado Pago". O evento passa a trazer `content_type`, `server` e `body_excerpt` — sem marcação, sem quebras de linha e truncado em 300 caracteres, porque vai para o log e não é lugar de HTML nem de conteúdo que o provedor possa ecoar (§43).

A sanitização é uma **varredura linear sem regex**, de propósito: `<[^>]*>` sobre corpo de terceiro é `rb/polynomial-redos` (CodeQL), porque uma entrada com muitos `<` sem fechamento faz o backtracking crescer com o tamanho. No Melhor Envio, truncar antes da regex não bastou para fechar o achado — só remover a regex fechou. Não reintroduzir regex aqui.

**`user_allowed_only_in_test` não é sobre o pagador.** O Mercado Pago devolve esse erro quando o meio de pagamento pedido **não está habilitado na conta do vendedor**. Confirmado consultando `GET /v1/payment_methods` com o token do artesão: a conta TESTUSER de sandbox lista 19 métodos (cartão de crédito, débito, pré-pago, boleto, saldo) e **PIX não está entre eles**. Antes de investigar credenciais ou pagador, consulte `/v1/payment_methods`: é uma chamada de leitura e responde direto.

**PIX não é testável no sandbox — e a explicação registrada aqui antes estava errada.** A conclusão anterior era que faltava cadastrar uma chave PIX na conta TESTUSER, e que isso se resolveria no painel do Mercado Pago. Não se resolve: a documentação oficial afirma que **pagamentos com PIX não podem ser feitos com credenciais de teste**, e a própria página de teste de integração recomenda escolher outro meio de pagamento para validar o QR Code nessa fase (ver "Posso pagar com Pix em ambiente de teste?" na ajuda e a seção de teste de integração de PIX na doc de desenvolvedores). A observação de `/v1/payment_methods` continua correta e é justamente o que se espera nesse cenário — PIX não aparece porque não existe para credencial de teste, não porque falte configuração. Consequências: **cartão** é o meio a usar no sandbox, com os cartões de teste do provedor; e **PIX só se valida em produção**, com conta real e cobrança de valor baixo — decisão de negócio, por envolver dinheiro real. Erro de método registrado (terceira ocorrência do mesmo padrão): a observação era boa, a causa foi inferida dela sem consultar a documentação.

## Relação com o pedido

* Pagamento aprovado deve confirmar o pedido (`Order` transita para `confirmed` — ver `docs/checkout.md` e `docs/domain.md`).
* Pagamento recusado não deve confirmar o pedido nem debitar estoque de forma definitiva.

`TODO — DECISION REQUIRED`: a política exata de quanto tempo um pedido `pending` aguarda confirmação de pagamento antes de liberar o estoque reservado (se houver reserva) não está definida — depende da modelagem de estoque escolhida na Fase 8 e deve ser uma decisão de negócio.
