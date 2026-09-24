# Architecture

Este documento descreve a arquitetura técnica do sistema. Para regras de negócio, ver `docs/domain.md`. Para o que já está implementado e o que ainda não existe, ver `ROADMAP.md`.

## Estilo arquitetural

Monólito modular em Ruby on Rails.

Não utilizar microservices, filas externas de mensageria entre serviços, ou split de banco de dados sem um requisito explícito que justifique a complexidade adicional.

## Stack

* Ruby on Rails
* PostgreSQL (fonte de verdade dos dados)
* Hotwire (Turbo + Stimulus) para o frontend
* Tailwind CSS
* Active Storage para upload de mídia (imagens de produto)
* Solid Queue para jobs assíncronos
* Solid Cache para cache
* Solid Cable para funcionalidades realtime (quando necessário)
* Minitest + Capybara para testes
* Docker para ambiente de desenvolvimento
* GitHub Actions para CI

## Camadas

```text
Browser
   ↓
Controllers
   ↓
Domain / Models
   ↓
PostgreSQL
```

* **Controllers**: recebem a requisição, autorizam, validam parâmetros, chamam o domínio e renderizam/redirecionam. Não contêm regra de negócio.
* **Domain / Models**: Active Record models representando as regras e invariantes do negócio. Service Objects são usados apenas para operações realmente complexas que não se encaixam naturalmente em um model (ex.: `Checkout::CreateOrder`), nunca como padrão automático.
* **PostgreSQL**: fonte de verdade. Toda alteração estrutural ocorre por migration. Invariantes críticas (unicidade, integridade referencial) são reforçadas também no banco (constraints, unique index), não apenas em validações Rails.

## Organização por domínio de negócio

O código deve ser organizado refletindo os domínios de negócio, não apenas a estrutura padrão MVC do Rails. Principais domínios (ver `docs/domain.md` para as entidades de cada um):

* Catalog
* Customers
* Cart
* Checkout
* Orders
* Payments
* Shipping
* Inventory
* Discounts
* Reviews
* Notifications
* Admin

O domínio de negócio não deve depender diretamente de detalhes de infraestrutura quando isso puder ser evitado (ex.: o domínio de pagamento não deve conhecer detalhes específicos de um gateway — ver ADR 003 em `docs/decisions/003-payment-gateway.md`).

## Escopo atual vs. futuro

A arquitetura acima é o alvo de longo prazo. O `ROADMAP.md` define o que é construído em cada fase — o MVP (Fases 0–7) implementa apenas os domínios Catalog, Cart, Customers, Checkout, Orders e Payments, em sua forma mais simples possível. Inventory, Shipping e Discounts em sua forma completa (peça única, sob encomenda, variantes, frete real, cupons) são pós-MVP.

## Frontend

Hotwire é o padrão (Turbo Drive, Turbo Frames, Turbo Streams, Stimulus). Não introduzir React ou outro framework SPA sem uma justificativa arquitetural explícita e aprovada — ver `CLAUDE.md`, seção "Views"/"Hotwire".

## Autenticação e autorização

* MVP: autenticação de administrador via o gerador de authentication nativo do Rails; autenticação de cliente (`Customer`) com e-mail/senha.
* Autorização deve sempre ser verificada no servidor, nunca inferida a partir da UI (links escondidos) ou de dados enviados pelo cliente.

Decidido na Fase 14/18: implementação simples (sem gem dedicada como Pundit) — `User#role` (hoje só `admin`) checado centralmente em `Admin::BaseController#require_admin!`. Reavaliar uma gem só se/quando existirem múltiplos papéis com permissões que variem por recurso — ver `docs/security.md`.

## Observabilidade (Fase 19)

A aplicação usa os eventos estruturados nativos do Rails 8.1 (`Rails.event`), sem gem de APM. Em produção, `Observability::JsonEventSubscriber` escreve JSON de uma linha em `STDOUT`, que a Railway reconhece e indexa por atributo. O subscriber cobre os eventos que o próprio Rails emite para requests e Active Job, além destes marcos do domínio:

* `checkout.order_created`
* `payment.attempt_created`
* `payment.webhook_applied`

Os payloads de domínio contêm somente IDs internos, valores em centavos, gateway e status — nunca e-mail, endereço, personalização ou credencial. `config.active_job.log_arguments = false` impede que argumentos de mailers/jobs levem dados pessoais para os logs. `Observability::JsonErrorSubscriber` registra classe, origem, severidade e até dez frames do backtrace, mas deliberadamente não registra a mensagem da exceção nem contexto arbitrário fornecido por código de aplicação.

O funil de compra agregado usa a tabela `funnel_events`, com contadores por dia e dimensões opcionais de produto/vendedor. Os eventos permitidos são `view_catalog`, `view_product`, `add_to_cart`, `checkout_started`, `payment_started`, `order_confirmed` e `payment_failed`. Não há cliente, sessão, IP, UTM ou payload de gateway nessa tabela; receita só entra como total em centavos no evento de pedido confirmado. O `upsert` é aditivo e concorrente, e a confirmação é registrada na transição idempotente do webhook, não no retry do job de notificação.

Cada request recebe `request_id` e método no contexto do Event Reporter. Somente eventos explicitamente permitidos são exportados: conclusão de request, Active Job e os eventos de checkout/pagamento acima. Eventos de início de request, parâmetros, argumentos de job, mensagens de exceção e URLs de redirect não saem no JSON, evitando que entrada do cliente ou tokens presentes em URLs virem telemetria. Consultas úteis no Log Explorer da Railway:

```text
@event:action_controller.request_completed AND @status:>=500
@event:action_controller.request_completed AND @duration_ms:>500
@event:active_job.completed AND @level:error
@event:payment.webhook_applied
@request_id:<id>
```

`GET /up` continua sendo liveness (o processo Rails iniciou). `GET /ready` é readiness: executa `SELECT 1` no banco primário e responde `503` com corpo genérico quando essa dependência essencial não está disponível. O healthcheck de deploy em `.railway/railway.ts` aponta para `/ready`, evitando promover uma aplicação que iniciou mas não acessa o banco.

A Railway já coleta CPU, memória, disco, rede e logs. Alertas de volume estão declarados na IaC. Monitores de CPU/RAM e destino de alertas (e-mail, Slack ou Discord) são configuração operacional da conta/plano e não foram escolhidos automaticamente pelo código.

Validação em produção realizada em 2026-08-31: `railway config plan` sem drift, `/ready` público com 200 e evento `action_controller.request_completed` confirmado no Log Explorer com status, duração, tempos de banco/view, queries e `request_id`.

Na mesma data, o dashboard do ambiente `production` foi criado com blocos de disco, rede, memória, CPU, logs de erro e uso/custo. O app Slack `EloShop Railway Alerts` publica no canal `#novo-canal`; o webhook do projeto está limitado a falha, crash e OOM de deployment, alerta de volume e eventos de monitor, sem ambientes efêmeros de PR. A URL é uma credencial e não deve ser copiada para código, documentação ou logs.

Monitores de threshold de CPU/RAM exigem o plano Pro e a interface da conta atual não oferece `Add monitor`. A regra Slack já inclui `Monitor Triggered`, portanto não precisa ser refeita quando esse recurso estiver disponível. Não fazer upgrade pago sem decisão explícita do negócio.

### Painel de observabilidade no Admin

`/admin/observability` mostra CPU/RAM atuais e p50/p95/p99/taxa de erro HTTP da última hora, consultando a API GraphQL pública da Railway (`Observability::RailwayMetricsReport`) — mesmo padrão do dashboard do Google Analytics (`Analytics::GoogleAnalyticsReport`): `configured?`/`configuration_issues` degradam para um aviso de configuração, cache de 15 minutos evita transformar cada visita ao Admin numa chamada externa, e falha do provedor vira mensagem genérica sem vazar detalhe técnico.

**Prometheus + Grafana foram avaliados e descartados** (2026-09-24): exigiriam hospedar dois serviços adicionais na Railway (~$10-16/mês de uso estimado, além de disco para retenção de séries) para uma cobertura já coberta pela combinação Sentry Performance (já ativo, `traces_sample_rate` em `config/initializers/sentry.rb`) + API nativa de métricas da Railway. A API da Railway venceu por não exigir infraestrutura nova nem gem de instrumentação (`yabeda`/`prometheus-client`).

Configuração necessária: só `RAILWAY_API_TOKEN` (Project token, gerado em Project Settings → Tokens, escopado ao ambiente `production` — não usar um Account token, que tem acesso a todos os projetos). `RAILWAY_PROJECT_ID`, `RAILWAY_SERVICE_ID` e `RAILWAY_ENVIRONMENT_ID` já existem automaticamente em todo serviço da Railway, injetadas pela própria plataforma — nada a configurar ali.

Sem `RAILWAY_API_TOKEN`, `/admin/observability` mostra a tela de configuração pendente em vez de quebrar.

O schema GraphQL público da Railway não é documentado publicamente campo a campo — a primeira versão do serviço (PR #125) usou uma query de `metrics` sem os argumentos obrigatórios (`measurements`, `startDate`) e assumiu que `httpMetrics` devolvia `p50`/`p95`/`p99`/`errorRate` prontos, o que não existe: cada resultado é uma série de amostras (`ts`/`value`), sem resumo agregado. As queries corretas, confirmadas por introspection contra a API real (2026-09-24):

* `metrics(serviceId:, environmentId:, measurements:, startDate:)` — série por `measurement` (`CPU_USAGE`, `MEMORY_USAGE_GB`), usa-se o ponto mais recente
* `httpDurationMetrics(serviceId:, environmentId:, startDate:, endDate:)` — série de janelas com `p50`/`p90`/`p95`/`p99` cada; usa-se a mais recente
* `httpMetricsGroupedByStatus(serviceId:, environmentId:, startDate:, endDate:)` — contagem por `statusCode`; taxa de erro e total são somados no lado do consumidor, não vêm prontos

Todas exigem `startDate`/`endDate` (ou só `startDate`) como `DateTime!` explícito — sem atalho como `hoursBack`.

A medição sob tráfego real foi feita em duas rodadas, sempre agregando os logs sem expor IP, user agent ou requisições individuais, e sem gerar carga artificial. A primeira (2026-08-31) encontrou só 20 requisições em 24 h, sem nenhuma no catálogo, e foi inconclusiva. A segunda (2026-09-01) somou 7.795 requisições em 7 dias e um recorte de 3h22 de navegação real com 240 requisições, já com o catálogo incluído — e fechou o critério.

O resultado: home 33 ms (p50), admin 27 ms, painel do vendedor 30 ms, Active Storage 24 ms — e catálogo `/produtos` em **1012 ms (p50) / 1497 ms (p95)**. Os eventos `action_controller.request_completed` localizaram o custo: as cinco cargas do catálogo fizeram 14 queries cada (sem regressão na contagem — a correção de N+1 da Fase 17 segue válida) gastando 959–1314 ms de `db_runtime`, isto é 68–94 ms por query, enquanto o admin, na mesma janela e no mesmo banco, rodou a 0,88 ms por query. A diferença de ~88x descarta banco lento ou throttling do plano e aponta as queries do próprio catálogo. Duas requisições terminaram em 499, com o cliente desistindo antes da resposta. O EXPLAIN ANALYZE refutou duas hipóteses em sequência: o `COUNT(DISTINCT ...)` custa 0,073 ms, e remover o `.distinct` deixa a query em ~1070 ms. A causa raiz é o **JIT do PostgreSQL**. O `includes` combinado com `with_attached_main_image` obriga o Active Record a resolver tudo em uma única `SELECT DISTINCT`, com 15 JOINs e ~130 colunas; isso infla o custo *estimado* do plano para 2,5M (estimativa falsa de 985.759 linhas para devolver 12) e ultrapassa o `jit_above_cost` (padrão 100000). O banco então compila 120 funções — `Optimization 791,9 ms`, `Emission 780,5 ms`, `JIT Total 1635,8 ms` — para executar uma query cujo `Unique`/`Sort` real custa 0,03 ms sobre 54 buffers. Variável única, sem alterar a query: `jit=on` 1387/1244/1247 ms contra `jit=off` 47/25/24 ms.

A aparente divergência local×produção não existia: era o *query cache* do Active Record servindo as execuções seguintes na medição local (1400 ms → 8,2 ms → 6,5 ms, marcadas `[CACHED]`). Com o cache desligado, o local reproduz produção em todas as rodadas (1215–1557 ms) — coerente com o JIT, que é pago por execução e nunca cacheado. Toda medição local de custo de query deve rodar em `ActiveRecord::Base.uncached`.

Correção aplicada: `ProductsController#index` usa `preload` (associações e `main_image_attachment: :blob`) no lugar de `includes` + `with_attached_main_image`. Cada associação vira sua própria query pequena, o plano nunca atinge o limiar do JIT, e a ação cai de ~1285 ms para ~10 ms, sem bloco `JIT` no plano (planning 0,320 ms, execution 0,134 ms). Validado em produção em 2026-09-01 (PR #30, deploy `6e41b0e` com `SUCCESS`): os eventos `action_controller.request_completed` do deploy novo mostram `/produtos` em 56,7/40,3/42,5 ms com `db_runtime` de 19,6/9,1/9,9 ms, contra 1012 ms (p50) e 959–1314 ms de banco antes — ~24x na duração e ~100x no banco. O `db_runtime` de ~10 ms é a confirmação direta de que o JIT deixou de ser compilado. A contagem sobe de 14 para 17 queries por construção, já que `preload` troca um JOIN monolítico por queries pequenas. A amostra são 3 requisições deliberadas, não tráfego orgânico: bastam para validar a correção, mas o p50/p95 sob carga real merece releitura quando houver volume.

Duas decisões seguem em aberto, ambas fora do escopo da correção: a PDP tem a mesma causa em escala menor (`related_products` também usa `includes` + `with_attached_main_image`; `db_runtime` de 83,75 ms medido na mesma janela, contra ~10 ms do catálogo já corrigido), e ajustar `jit_above_cost` no PostgreSQL da Railway protegeria qualquer query futura com plano superestimado, mas é mudança de infraestrutura com efeito global.

## Google Analytics no Admin

O Analytics tem duas partes independentes. A vitrine pública carrega o `gtag.js` somente depois de consentimento explícito; carrinho, checkout, pedidos, conta do comprador, painel do artesão e Admin nunca recebem o controller de rastreamento. Mesmo nas páginas permitidas, a aplicação envia caminhos virtuais estáveis (`/inicio`, `/catalogo`, `/produto`, `/artesao` etc.), sem slug, ID, query string, e-mail ou URL real. Google Signals e personalização de anúncios ficam desligados. A preferência dura 180 dias e pode ser reaberta no rodapé.

O Admin consulta a Google Analytics Data API por uma conta de serviço com acesso somente de leitura. `/admin` mostra usuários ativos, sessões e visualizações dos últimos 30 dias; `/admin/analytics` acrescenta evolução diária e as dez páginas virtuais mais acessadas. O resultado fica em cache por 15 minutos para não transformar cada visita ao Admin numa chamada externa. Falha ou configuração ausente degrada para um aviso e não derruba o dashboard. A chave JSON nunca entra no banco, HTML ou log; somente a classe do erro da consulta é emitida em evento estruturado.

O mesmo dashboard mostra o funil próprio da EloShop nos últimos 30 dias: visualizações públicas, carrinhos e checkouts iniciados, pedidos pagos, taxa de conversão, conversão do checkout e receita confirmada. Essas métricas são independentes do consentimento do GA4 e continuam disponíveis quando a integração externa está ausente.

## Termos comerciais do artesão

O cadastro do artesão apresenta os Termos Comerciais do Marketplace em uma
versão imutável (`SellerTerms::VERSION`) e exige checkbox explícito. O aceite
grava a versão, o texto integral, o SHA-256 do texto, data/hora, usuário,
vendedor, IP e user-agent em `seller_terms_acceptances`. Vendedores criados
antes da implantação ou diante de uma nova versão são redirecionados para o
aceite antes de acessar o painel; `Product#publish!` repete a barreira no
domínio para impedir publicação por qualquer outra porta.

O texto é uma minuta operacional: comissão de 15% sobre produtos após
descontos (sem frete), tarifas do Mercado Pago, repasses, reembolsos,
chargebacks, responsabilidades fiscais, suspensão, encerramento e alterações
contratuais devem ser revisados e aprovados por advogado antes da operação
comercial. Alterações exigem nova versão e novo aceite quando aplicável.

Configuração necessária:

* `GOOGLE_ANALYTICS_MEASUREMENT_ID` — identificador `G-...` do fluxo Web; habilita a coleta consentida.
* `GOOGLE_ANALYTICS_PROPERTY_ID` — ID numérico da propriedade GA4 usado pela Data API.
* `GOOGLE_ANALYTICS_CREDENTIALS_JSON` — JSON integral da conta de serviço. É segredo e deve ficar numa variável privada da Railway. A conta precisa ser adicionada como Leitor na propriedade, e a Google Analytics Data API precisa estar habilitada no projeto Google Cloud correspondente.

## Deploy (Fase 20)

**Decisão**: Railway (PaaS), não Kamal — `config/deploy.yml` fica no repositório sem uso, preservado para uma eventual migração futura pra VPS própria, mas o deploy real hoje é via Dockerfile + configuração da Railway. Sem domínio próprio ainda — usa o subdomínio `*.up.railway.app` que a Railway atribui automaticamente.

### O que a Railway precisa ter configurado

* **Build**: Dockerfile na raiz do repo. A configuração do serviço (builder `DOCKERFILE`, `dockerfilePath`, healthcheck `/ready`, `restartPolicyMaxRetries`) vive em `.railway/railway.ts` e está **gravada no próprio serviço** — ver "Infrastructure as Code" abaixo. O `railway.json` foi removido.
* **Postgres**: um único addon Postgres gerenciado pela Railway, expõe `DATABASE_URL`. `config/database.yml` faz o parse dessa URL e cria 4 bancos dentro da mesma instância (`<nome>`, `<nome>_cache`, `<nome>_queue`, `<nome>_cable`) — necessário porque `db:prepare` não carrega corretamente o schema de cache/queue/cable quando os 4 papéis compartilham literalmente o mesmo banco (testado localmente, ver comentário em `database.yml`).
* **Volume persistente**: anexar um volume ao serviço e apontar `RAILS_STORAGE_PATH` pro mesmo caminho do mount (`config/storage.yml`, serviço `production`) — sem isso, imagens de produto (Active Storage) são perdidas a cada redeploy, já que o resto do filesystem do container é efêmero.
* **Variáveis de ambiente obrigatórias**:
  * `RAILS_MASTER_KEY` — valor de `config/master.key` (nunca commitado; configurar direto no painel da Railway)
  * `DATABASE_URL` — injetada automaticamente pelo addon Postgres da Railway
  * `RAILS_STORAGE_PATH` — caminho do volume persistente (ver acima)
  * `MERCADO_PAGO_MARKETPLACE_APP_ID`, `MERCADO_PAGO_MARKETPLACE_CLIENT_SECRET` e `MERCADO_PAGO_MARKETPLACE_REDIRECT_URI` — aplicação OAuth Marketplace; os valores são preservados pelo IaC sem entrar no repositório
  * `MERCADO_PAGO_MARKETPLACE_ACCESS_TOKEN` — Access Token de produção da aplicação Marketplace, usado somente pela conciliação do Sales Report em `/admin/financials`; é diferente do Client Secret e dos tokens OAuth dos artesãos, e também é preservado pelo IaC sem entrar no repositório
  * `MERCADO_PAGO_MARKETPLACE_SANDBOX=true` — somente durante a validação com aplicação/conta de teste; remover ou definir `false` antes do onboarding real
  * `MELHOR_ENVIO_CLIENT_ID`, `MELHOR_ENVIO_CLIENT_SECRET` e `MELHOR_ENVIO_REDIRECT_URI` — aplicação OAuth do Melhor Envio (frete real, ADR 005); sem elas o painel mostra "aguarda a configuração" e o checkout usa a tabela interna de frete
  * `MELHOR_ENVIO_SANDBOX=true` — somente durante a validação com a conta de teste do Melhor Envio (saldo fictício); remover ou definir `false` antes de cotar frete real
  * `GOOGLE_ANALYTICS_MEASUREMENT_ID`, `GOOGLE_ANALYTICS_PROPERTY_ID` e `GOOGLE_ANALYTICS_CREDENTIALS_JSON` — opcionais; habilitam respectivamente a coleta consentida na vitrine e os relatórios agregados do Admin. O JSON da conta de serviço é segredo e nunca deve ser versionado
  * `RAILS_ENV=production` (Railway/Dockerfile já cobre isso, mas confirmar)
  * `SENTRY_DSN` — opcional; sem ela, `config/initializers/sentry.rb` não ativa o SDK e a aplicação sobe normalmente. DSN do projeto `eloshop` no Sentry SaaS (eloshop.sentry.io) — até 2026-09-16 apontava para um GlitchTip auto-hospedado; a troca só mudou o valor da variável, o SDK `sentry-ruby`/`sentry-rails` é o mesmo. Só o error tracking do backend está ligado, sem SDK JS nem Session Replay — decisão deliberada para não expor dados de checkout (nome, endereço) capturados em gravação de tela. Ao testar via `railway run`, o comando roda localmente com `RAILS_ENV` do shell (não sobrescrito para `production`), então o initializer não ativa — use `RAILS_ENV=production railway run ...` para reproduzir o guard corretamente. **`railway run` não serve para consultar o banco de produção**: como roda local, o `DATABASE_URL` do serviço aponta para `postgres.railway.internal`, host que só resolve dentro da rede da Railway, e a falha aparece como `ActiveRecord::NoDatabaseError: Database not found: railway` — enganosa, porque parece banco inexistente. Para ler o banco de produção use `railway ssh --service eloshop-web 'bin/rails runner "..."'`, que executa dentro do contêiner (foi o método usado no diagnóstico da PDP e na apuração do estado do Mercado Pago).
* **Porta**: a Railway atribui `$PORT` dinamicamente; `bin/docker-entrypoint` já repassa isso pro Thruster (`HTTP_PORT`) — nada a configurar manualmente, mas é importante saber que existe essa ponte (ver comentário no arquivo).
* **TLS**: a Railway termina HTTPS na borda e encaminha HTTP puro pro container — por isso `config.assume_ssl = true` (além de `config.force_ssl = true`, decidido na Fase 18) em `config/environments/production.rb`.

### Infrastructure as Code (`.railway/railway.ts`)

A Railway descontinuou o Config as Code (`railway.json`/`railway.toml`), que funcionava até 2026-12-01. A configuração passou para `.railway/railway.ts`, versionado, e foi aplicada com `railway config apply`.

O arquivo foi gerado a partir do estado real do projeto (`railway config pull`), **não** da tradução automática (`railway config migrate`). A tradução é lossy: emite `builder` e `dockerfilePath` como comentário. Esses dois campos estavam gravados como `null` no serviço — só existiam em tempo de deploy, injetados pelo `railway.json` (visível no `propertyFileMapping` de cada deployment). Migrar pela tradução e apagar o `railway.json` teria deixado o serviço sem builder, caindo para **Railpack** em vez do Dockerfile, além de sem healthcheck.

Por isso a ordem importou: `apply` primeiro, remoção do `railway.json` só depois de confirmar a configuração gravada no serviço.

`restartPolicyType` está deliberadamente ausente do arquivo: `ON_FAILURE` é o default da Railway e a API grava `null` ao recebê-lo, o que deixava o `plan` acusando uma mudança pendente que nunca se resolvia. `restartPolicyMaxRetries` continua explícito, porque o default é 10.

Rodar `railway config plan` / `apply` exige o SDK (`npm install railway` na raiz). O projeto não tem toolchain Node — `node_modules/` está no `.gitignore` e nada de Node entrou no `Dockerfile` nem no CI. Comandos úteis:

```bash
railway config plan     # mostra drift entre o arquivo e a Railway; não altera nada
railway config apply    # aplica
railway config pull     # importa o estado real para o arquivo
```

### Deploy automático a partir do GitHub

O serviço `eloshop-web` está conectado ao repositório `urieljuliatti85/eloshop`, branch `main` — todo push no `main` dispara build e deploy, sem `railway up` manual. Antes disso os deploys eram uploads do diretório local pelo CLI, o que significava que o código em produção não tinha nenhuma garantia de corresponder ao que estava versionado.

O deployment trigger está com **"Wait for CI" ligado** (`DeploymentTrigger.checkSuites = true`): a Railway só builda depois que os check suites do GitHub passam. Ou seja, um push que quebre lint, testes, Brakeman ou bundler-audit não chega em produção. A contrapartida é que **um workflow de CI quebrado bloqueia todo deploy automático** — foi exatamente o que aconteceu antes desta configuração, com `.github/workflows/ci.yml` inválido por um `*` no valor de `DATABASE_URL`, que fazia o arquivo inteiro falhar no parse do YAML e nenhum job rodar.

Configuração feita via CLI (não há nada disso versionado no repositório — é estado do lado da Railway):

```bash
railway service source connect --repo urieljuliatti85/eloshop --branch main --service eloshop-web
railway api 'mutation($id: String!, $input: DeploymentTriggerUpdateInput!) {
  deploymentTriggerUpdate(id: $id, input: $input) { id checkSuites }
}' --var id=<trigger-id> --variables '{"input":{"checkSuites":true}}'
```

Para inspecionar ou reverter: `railway api 'query { deploymentTriggers(projectId: ..., environmentId: ..., serviceId: ...) { edges { node { id branch checkSuites } } } }'` e `railway service source disconnect --service eloshop-web`.

**Essa configuração já se perdeu uma vez, silenciosamente.** Em 2026-09-07 o deploy de `eae9ba7` foi investigado por curiosidade e revelou `checkSuites: false`: o build começou **um segundo antes** do CI iniciar e terminou **17 s antes** do CI concluir — ou seja, a proteção descrita acima não estava valendo, embora esta documentação afirmasse que sim. Ao religar, o `id` do trigger mudou (`410015f0…` → `383b4ae8…`), o que indica que o trigger é **recriado**, e não atualizado, quando a fonte do GitHub é reconectada — e um trigger novo nasce com `checkSuites` no default `false`. Portanto: **toda vez que rodar `railway service source connect`, refaça a mutation de `checkSuites` e confirme com a query**, porque a reconexão desfaz a proteção sem nenhum aviso.

Não há alarme para isso: a configuração não é versionada e nada no repositório detecta a divergência. Enquanto não existir uma verificação automática, a evidência confiável de que a proteção está valendo é comparar horários — o deploy precisa **começar depois** do CI concluir —, nunca o fato de o build ter iniciado.

**CI vermelho descarta o deploy, e um rerun verde NÃO o recupera** (observado em 2026-09-13 com `19e2095`). A sequência foi: push, CI falha, a Railway marca o deploy como **`SKIPPED`** segundos depois (19:39:23 o CI, 19:39:29 o descarte). O job foi reexecutado e ficou verde nos seis, mas **nenhum deploy novo foi disparado**: o gatilho reage ao check suite do push, e um rerun manual não gera esse evento. Resultado: o commit fica no GitHub com CI verde e **fora de produção**, sem nada sinalizando a diferença.

Pior, `latestDeployment` na API da Railway aponta para o último deploy **bem-sucedido**, ignorando o `SKIPPED` — então consultar só o status devolve `SUCCESS` de um commit anterior e parece confirmar um deploy que não aconteceu. **Confira sempre o `commitHash` junto do status**, nunca o status sozinho; é o mesmo erro de método do §51 (sinal indireto em vez de evidência), aqui na forma de um campo que responde a outra pergunta. Para retomar um commit descartado: `railway redeploy`, ou um commit novo por cima — o rerun não basta.

Isso torna um **teste instável mais caro do que parece**: ele não custa só um CI vermelho, ele descarta silenciosamente o deploy daquele commit. Ver o TODO do `seller_portal_mobile_test.rb` no ROADMAP.

### Achado corrigido durante a Fase 20

`rswag-api`/`rswag-ui` estavam no grupo `development, test` do `Gemfile`, mas são montados em `/api-docs` em todos os ambientes (`config/routes.rb`) — o app quebrava no boot de produção (`uninitialized constant Rswag`) porque essas gems nunca eram exigidas fora de dev/test. Movidas para fora do grupo; só `rswag-specs` (a DSL usada nos specs) continua dev/test-only.

## Multi-tenancy / marketplace

**Decisão tomada** (ADR 004, `docs/decisions/004-marketplace-model.md`): o sistema é um marketplace real, não uma loja única. Múltiplos artesãos vendem como entidades comerciais independentes (`Seller`).

A Fase 22 introduziu `Seller`, o papel `User#seller` e o vínculo obrigatório `Product#seller`. A unicidade de `sku`/`slug` é composta com `seller_id`; produtos legados foram migrados para o vendedor aprovado `EloShop`. O painel `SellerPortal` nunca aceita `seller_id` da requisição: todos os recursos partem de `Current.user.seller`. A vitrine e `Product#available_for_purchase?` exigem vendedor aprovado, e o carrinho rejeita mistura de vendedores enquanto o split 1:N não está disponível.

O onboarding financeiro usa OAuth Authorization Code do Mercado Pago. O KYC nível 6 é feito e mantido pelo próprio Mercado Pago; a aplicação não recebe documentos. `Seller` persiste `mercado_pago_user_id`, datas e tokens cifrados com `ActiveSupport::MessageEncryptor`/`secret_key_base`. O `state` OAuth é aleatório, armazenado como digest na sessão, expira em 10 minutos e é comparado em tempo constante. A conexão não implica aprovação automática porque a resposta OAuth pública não contém o nível KYC: a plataforma confirma o KYC explicitamente. Desconectar suspende a publicação ao retornar o vendedor para `pending`.

Desde a Fase 23, `Order` agrega `SellerOrder`s, aos quais pertencem itens, fulfillment/frete, snapshot financeiro e responsabilidades operacionais. `Payment` registra a comissão do split, tarifa do processador e reembolsos. No primeiro lançamento, cada checkout tem exatamente um vendedor/`SellerOrder`; multi-vendedor depende de acesso comercial ao split 1:N do Mercado Pago.
