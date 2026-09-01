# ROADMAP.md

## E-commerce de Artesanato

Este documento define a sequência de implementação do e-commerce.

O roadmap é dividido em duas partes:

- **MVP** (Fases 0 a 7): o menor sistema possível capaz de vender um produto simples, do catálogo ao pagamento.
- **Pós-MVP** (Fases 8 em diante): funcionalidades avançadas do domínio de artesanato (peça única, sob encomenda, personalização, variantes, frete real, cupons, administração completa, SEO, etc.).

Nenhuma funcionalidade avançada deve ser iniciada antes do fluxo mínimo estar funcional, testado e revisado:

```text
Produto → Catálogo → Carrinho → Checkout → Pedido → Pagamento
```

Cada fase deve estar funcional, testada e revisada antes do início da próxima, salvo dependência explicitamente documentada.

---

# Status

Legenda:

* `[ ]` Não iniciado
* `[~]` Em andamento
* `[x]` Concluído
* `[!]` Bloqueado

---

# PARTE 1 — MVP

## FASE 0 — Fundação técnica

Status: `[x]`

### Objetivo

Criar a base técnica do projeto, sem nenhuma funcionalidade de negócio.

### Funcionalidades

Nenhuma funcionalidade de produto. Apenas infraestrutura de desenvolvimento.

### Modelos envolvidos

Nenhum.

### Migrations necessárias

Nenhuma.

### Testes

* Suite de testes (Minitest) executando, mesmo vazia
* CI executando com sucesso em um commit trivial

### Painel do vendedor e admin

Medição posterior, mesma metodologia (requisição real, warmup, `payload[:cached]` descontado), sobre uma árvore de profundidade 3 crescendo de 20 para 115 categorias:

| página | antes (20 → 115 cat.) | crescimento | depois |
| --- | --- | --- | --- |
| `admin/categories/index` | 11 → 30 | +0,20/categoria | 5 → 5 |
| `admin/products/new` | 18 → 75 | +0,60/categoria | 6 → 6 |
| `admin/categories/new` | 16 → 73 | +0,60/categoria | 4 → 4 |

O achado corrigiu duas suposições registradas antes:

* `admin/categories/index`, apontado como o alvo principal, era o **menos** afetado — o `includes(:parent, :products)` do controller já absorvia a maior parte, e o resto vinha de `breadcrumb_name` subindo além do pai (só categorias de profundidade ≥ 3 pagavam).
* Os **formulários** eram o problema real, a 3× a taxa: montavam `Category.order(:name).map(&:breadcrumb_name)` na própria view, sem `includes`. O mesmo código estava em `seller_portal/products/_form`, introduzido pela Fase 22 — esse não é admin de baixo tráfego, e foi o que derrubou a justificativa original para não corrigir.

A correção move a consulta para os controllers (§54) e usa o `Category::Tree` que já existia; `Tree#parent` foi acrescentado para a coluna "categoria pai" da listagem, e a contagem de produtos virou um `group(:category_id).count` no lugar de `category.products.size` por linha.

### Critérios de aceite

* [x] Aplicação Rails criada
* [x] PostgreSQL configurado e acessível localmente
* [x] Docker configurado
* [x] Git e `.gitignore` configurados
* [x] Variáveis de ambiente e Rails Credentials configurados
* [x] Tailwind e Hotwire instalados
* [x] Minitest e Capybara configurados
* [x] Lint configurado
* [x] CI configurado e executando
* [x] Aplicação inicia localmente sem erros

### Dependências de outras fases

Nenhuma.

---

## FASE 1 — Produto

Status: `[x]`

### Objetivo

Permitir que um administrador cadastre um produto simples, com estoque numérico básico, de forma protegida por autenticação.

Escopo intencionalmente restrito: **sem** variantes, personalização, peça única, sob encomenda ou pré-venda — isso é pós-MVP (Fase 9/10/... ). Aqui existe apenas "produto com estoque padrão".

### Funcionalidades

* Autenticação mínima de administrador (Rails built-in authentication)
* CRUD de produto no admin: nome, slug, descrição, preço, SKU, quantidade em estoque, status
* Upload de imagem principal do produto (Active Storage)
* Ciclo de vida simples do produto: `draft → active → sold_out → discontinued`

### Modelos envolvidos

* `Product`
* `User` (administrador — via `bin/rails generate authentication`)

### Migrations necessárias

* `create_users` (gerado pelo generator de authentication do Rails)
* `create_products`:
  * `name` (string, not null)
  * `slug` (string, not null, unique index)
  * `description` (text)
  * `price_cents` (integer, not null)
  * `currency` (string, not null, default `BRL`)
  * `sku` (string, not null, unique index)
  * `stock_quantity` (integer, not null, default 0)
  * `status` (string/enum, not null, default `draft`, com index)
  * `timestamps`
* Instalação das tabelas do Active Storage (`active_storage:install`)

### Testes

* Model: unicidade de `slug` e `sku` (validação + índice único), validação de `price_cents` não negativo, transições de status válidas/inválidas
* Autorização: usuário não autenticado não acessa o admin de produtos; autenticado acessa

### Critérios de aceite

* [x] Administrador consegue autenticar
* [x] Administrador consegue criar, editar, publicar e despublicar um produto
* [x] Administrador consegue anexar imagem principal
* [x] `slug` e `sku` são únicos e validados também no banco (unique index)
* [x] Usuário não autenticado não acessa nenhuma rota administrativa, mesmo alterando a URL diretamente

### Dependências de outras fases

Fase 0.

### Decisões tomadas durante a implementação

* Transições de status permitidas: `draft → active`, `active → draft`, `active ⇄ sold_out`, `active/sold_out → discontinued`; `discontinued` é terminal.
* Upload de imagem principal: máximo 5MB, apenas `image/png`, `image/jpeg` e `image/webp` (default provisório — não é uma política de negócio definitiva).
* Rota raiz temporária (`root "admin/products#index"`) até o storefront público existir (Fase 2).

---

## FASE 2 — Catálogo (storefront de listagem)

Status: `[x]`

### Objetivo

Exibir os produtos ativos ao público, com página de listagem e página de produto.

### Funcionalidades

* Listagem paginada de produtos com status `active`
* Página individual do produto, acessível por slug
* Produto sem estoque (`stock_quantity` 0) exibido como indisponível, sem opção de compra
* Produto `draft`/`discontinued` não aparece na loja nem é acessível diretamente pela URL

### Modelos envolvidos

* `Product` (reaproveitado, sem novo modelo)

### Migrations necessárias

* Nenhuma nova, além de garantir índice em `products.status` (se não coberto na Fase 1)

### Testes

* Request/system: listagem mostra apenas produtos `active`
* Request/system: produto `draft`/`discontinued` retorna 404 mesmo com URL direta
* Produto esgotado exibe estado de indisponibilidade e não expõe ação de compra

### Critérios de aceite

* [x] Cliente acessa a listagem de produtos publicados
* [x] Cliente acessa a página de um produto por URL amigável (`/produtos/:slug`)
* [x] Produto esgotado é claramente identificado como indisponível
* [x] Produto não publicado é inacessível para o público

### Dependências de outras fases

Fase 1.

### Decisões tomadas durante a implementação

* `Product#to_param` passou a retornar o `slug` — isso afeta **todas** as rotas que recebem um `Product`, então o admin (Fase 1) também passou a localizar produtos por slug em vez de id numérico, unificando o identificador usado nas URLs em toda a aplicação.
* Escopo de visibilidade pública restrito literalmente a `status: active` (sem incluir `sold_out`), já que essa transição ainda não é alcançável na prática (é automática por estoque, prevista para a Fase 8).
* Paginação implementada manualmente com `limit`/`offset` (sem gem), 12 produtos por página.
* Sem nenhum placeholder de "comprar" — Carrinho é Fase 3.

---

## FASE 3 — Carrinho

Status: `[x]`

### Objetivo

Permitir que o cliente monte um pedido antes de finalizar a compra, com totais recalculados no servidor.

### Funcionalidades

* Adicionar produto ao carrinho
* Remover produto do carrinho
* Alterar quantidade
* Subtotal calculado sempre no servidor
* Carrinho persistido por sessão (`guest cart`, sem exigir login)
* Validação de disponibilidade ao adicionar/atualizar item

### Modelos envolvidos

* `Cart`
* `CartItem`

### Migrations necessárias

* `create_carts`:
  * `session_token` (string, not null, unique index)
  * `customer_id` (bigint, nullable, foreign key — preenchido só a partir da Fase 4)
  * `timestamps`
* `create_cart_items`:
  * `cart_id` (foreign key, not null)
  * `product_id` (foreign key, not null)
  * `quantity` (integer, not null, default 1)
  * `timestamps`
  * índice único em `(cart_id, product_id)`

### Testes

* Model: cálculo de subtotal a partir de `Product.price_cents` atual
* Model: não permite adicionar produto indisponível ou quantidade maior que o estoque
* Request/system: adicionar, remover e alterar quantidade refletem no total exibido

### Critérios de aceite

* [x] Cliente consegue adicionar, remover e alterar quantidade de itens
* [x] Total exibido é sempre calculado no servidor, nunca confiado do client
* [x] Produto indisponível não pode ser adicionado ao carrinho
* [x] Carrinho persiste entre requisições da mesma sessão

### Dependências de outras fases

Fases 1 e 2.

### Decisões tomadas durante a implementação

* `carts.customer_id` criado como bigint nullable, **sem** foreign key (a tabela `customers` só existe na Fase 4; a constraint será adicionada lá).
* Carrinho identificado por cookie assinado e permanente (`cart_token`), independente da sessão de autenticação do admin — mesmo padrão de `Current.session`, agora também `Current.cart`.
* Introduzido `StorefrontController` (base para controllers públicos: acesso sem login + resolução do carrinho atual), do qual `ProductsController`, `CartsController` e `CartItemsController` herdam.
* Adicionar um produto já presente no carrinho soma a quantidade ao item existente, em vez de erro de duplicidade.

### Achado de infraestrutura

A suíte de testes passou de 50 casos nesta fase, cruzando o limiar em que o Minitest passa a paralelizar via fork de processos. Nesta máquina, esse fork trava de forma reproduzível logo após o primeiro check de schema do Active Record no processo filho (sem uso de CPU, sem lock no Postgres). Causa raiz não investigada a fundo; paralelização desativada em `test/test_helper.rb` (`parallelize(workers: 1)`) como correção, já que a suíte continua rápida (~2s) mesmo sem paralelizar. Reavaliar se a suíte crescer muito.

---

## FASE 4 — Identificação do cliente e endereço

Status: `[x]`

### Objetivo

Capturar quem está comprando e para onde o pedido deve ser enviado, como etapa anterior ao checkout.

### Funcionalidades

* Cadastro/login de cliente (`Customer`) — pode ser feito como parte do próprio checkout
* Cadastro de endereço de entrega vinculado ao cliente
* Associação do carrinho da sessão ao cliente identificado

### Modelos envolvidos

* `Customer`
* `Address`

### Migrations necessárias

* `create_customers`:
  * `name` (string, not null)
  * `email` (string, not null, unique index)
  * `password_digest` (string, not null)
  * `timestamps`
* `create_addresses`:
  * `customer_id` (foreign key, not null)
  * `street`, `number`, `complement`, `neighborhood`, `city`, `state`, `zip_code` (strings, campos obrigatórios validados na aplicação)
  * `timestamps`

### Testes

* Model: unicidade de e-mail do cliente, validações de endereço obrigatório
* Request/system: cliente se cadastra, informa endereço e o carrinho da sessão passa a pertencer a ele

### Critérios de aceite

* [x] Cliente consegue criar conta e autenticar
* [x] Cliente consegue cadastrar um endereço de entrega
* [x] Carrinho existente na sessão é associado ao cliente após identificação
* [x] Cliente não identificado não avança para o checkout (mecanismo pronto — `AddressesController` já exige; o próprio checkout é Fase 5)

### Dependências de outras fases

Fase 3.

### Decisões tomadas durante a implementação

* Autenticação de cliente é totalmente paralela e independente da de administrador: `Customer`/`CustomerSession`/`CustomerAuthentication` espelham `User`/`Session`/`Authentication`, com cookie próprio (`customer_session_id`) e `Current.customer_session`. Testado e confirmado que login de um não concede acesso ao outro em nenhum sentido.
* `StorefrontController` não libera autenticação de cliente de forma geral — cada controller decide (`ProductsController`, `CartsController`, `CartItemsController`: totalmente abertos; `CustomersController`: aberto, é o próprio cadastro; `CustomerSessionsController`: aberto só em `new`/`create`, mesmo padrão já usado no `SessionsController` do admin; `AddressesController`: não libera nada, exige cliente autenticado em todas as ações).
* `add_foreign_key :carts, :customers` adicionado nesta fase, fechando a pendência deixada na Fase 3.
* Reaproveitado o `rate_limit` (10 tentativas / 3 min) já usado no login do admin, aplicado também ao cadastro e login de cliente.

---

## FASE 5 — Checkout

Status: `[x]`

### Objetivo

Transformar um carrinho validado em um pedido, com frete simplificado (valor fixo/manual — o cálculo real de frete é pós-MVP) e com todos os valores recalculados e revalidados no servidor.

### Funcionalidades

* Fluxo: `Carrinho → Endereço → Frete (valor fixo) → Resumo → Pagamento → Pedido`
* Revalidação de preço e disponibilidade de cada item no momento do checkout (preço/estoque podem ter mudado desde que foram adicionados ao carrinho)
* Débito de estoque com locking/transação, evitando venda concorrente acima do disponível
* Checkout idempotente (duplo clique ou retry não cria dois pedidos)
* Criação do `Order`/`OrderItem` com snapshot de nome, SKU, preço unitário e endereço de entrega no momento da compra

### Modelos envolvidos

* `Order`
* `OrderItem`
* (reaproveita `Cart`, `CartItem`, `Customer`, `Address`)

### Migrations necessárias

* `create_orders`:
  * `customer_id` (foreign key, not null)
  * `status` (string/enum, not null, default `pending`)
  * `subtotal_cents`, `shipping_cents`, `total_cents` (integer, not null)
  * `shipping_address_snapshot` (jsonb, not null)
  * `idempotency_key` (string, not null, unique index — usada para tornar o checkout seguro contra duplo envio)
  * `timestamps`
* `create_order_items`:
  * `order_id` (foreign key, not null)
  * `product_id` (foreign key, not null — apenas referência, não fonte de verdade)
  * `product_name`, `sku` (string, not null — snapshot)
  * `unit_price_cents` (integer, not null — snapshot)
  * `quantity` (integer, not null)
  * `timestamps`

### Testes

* Preço alterado entre adicionar ao carrinho e finalizar o checkout: servidor usa o preço revalidado, nunca o valor vindo do client
* Estoque insuficiente ou zerado no momento do checkout impede a finalização
* Teste de concorrência: duas requisições de checkout simultâneas para a última unidade de um produto — apenas uma deve ser bem-sucedida
* Reenvio do mesmo checkout (mesma `idempotency_key`) não cria um segundo pedido

### Critérios de aceite

* [x] Pedido é criado somente com valores recalculados no servidor
* [x] Estoque é debitado de forma atômica, sem venda além do disponível
* [x] Pedido preserva snapshot de produto e endereço
* [x] Checkout é idempotente
* [x] Falha em qualquer etapa não deixa pedido nem estoque em estado inconsistente

### Dependências de outras fases

Fase 4.

### Decisões tomadas durante a implementação

* **Frete fixo (decisão de negócio)**: R$ 15,00 para qualquer pedido no MVP — cálculo real via Correios fica para a Fase 12, conforme já previsto no roadmap (confirmado explicitamente com o usuário, que inicialmente pediu Correios já nesta fase; optamos por manter a fase como planejada).
* **Locking de concorrência**: lock pessimista (`SELECT ... FOR UPDATE`) por produto, em ordem estável (`product_id`) para evitar deadlock, dentro da transação de criação do pedido. Resolve o TODO de `docs/inventory.md`.
* **Idempotência**: chave gerada no servidor e guardada na sessão HTTP na tela de revisão; índice único em `orders.idempotency_key`; reenvio (inclusive concorrente, via `ActiveRecord::RecordNotUnique`) retorna o pedido já existente. Resolve o TODO de `docs/checkout.md`.
* **Defesa em profundidade**: `CHECK (stock_quantity >= 0)` no banco, além da validação Rails já existente.
* Lógica centralizada em `Checkout::CreateOrder` (Service Object) — exatamente o caso que `docs/architecture.md` já apontava como justificativa para essa abstração.
* Redirecionamento pós-checkout vai para a home com uma mensagem de confirmação; a página de detalhe do pedido é escopo da Fase 6.

---

## FASE 6 — Pedido (ciclo de vida mínimo)

Status: `[x]`

### Objetivo

Dar visibilidade ao pedido criado, tanto para o cliente quanto para o administrador, com um conjunto mínimo de estados.

### Funcionalidades

* Página de confirmação/detalhe do pedido para o cliente
* Estados mínimos: `pending → confirmed → cancelled` (estados de envio/entrega são pós-MVP, Fase "Pedidos avançado")
* Listagem de pedidos no admin

### Modelos envolvidos

* `Order` (reaproveitado — nenhum modelo novo)

### Migrations necessárias

Nenhuma nova, desde que a coluna `status` já tenha sido criada na Fase 5.

### Testes

* Model: transições de estado inválidas são rejeitadas (ex.: `cancelled → confirmed`)
* Request/system: cliente visualiza seu próprio pedido e não consegue visualizar pedido de outro cliente
* Request/system: administrador visualiza a lista de pedidos

### Critérios de aceite

* [x] Cliente consegue visualizar o status e os itens do próprio pedido
* [x] Cliente não consegue acessar pedido de outro cliente alterando a URL
* [x] Administrador consegue listar e visualizar pedidos
* [x] Transições de estado inválidas são bloqueadas

### Dependências de outras fases

Fase 5.

### Decisões tomadas durante a implementação

* Transições permitidas: `pending → confirmed`, `pending → cancelled`, `confirmed → cancelled`; `cancelled` é terminal — mesmo padrão (`ALLOWED_STATUS_TRANSITIONS`) já usado em `Product`.
* Nenhuma ação de UI para confirmar/cancelar foi exposta nesta fase — `confirm!` só terá gatilho real na Fase 7 (pagamento aprovado); os métodos existem e são testados, mas não há botão ainda.
* `OrdersController#create` passou a redirecionar para a página do pedido criado (`order_path`) em vez da home, já que agora ela existe.

---

## FASE 7 — Pagamento

Status: `[x]`

### Objetivo

Integrar um único gateway de pagamento e confirmar o pedido de acordo com o resultado do pagamento. **Esta fase fecha o MVP.**

### Funcionalidades

* Criação de `Payment` vinculado ao pedido, no status `pending`
* Abstração de gateway (`authorize` / `capture` / `verify_webhook`), isolando o domínio do fornecedor concreto (conforme ADR 003)
* Recebimento de webhook do gateway, autenticado e idempotente
* Atualização do status do pedido conforme o resultado: aprovado → `confirmed`; recusado → pedido permanece `pending`/vai para `cancelled`, sem baixar estoque duas vezes
* Nenhum dado sensível de cartão é armazenado — apenas token/identificador do gateway

### Modelos envolvidos

* `Payment`
* `PaymentEvent` (registro de eventos de webhook recebidos, para garantir idempotência)

### Migrations necessárias

* `create_payments`:
  * `order_id` (foreign key, not null)
  * `gateway` (string, not null)
  * `external_id` (string, not null — identificador do gateway)
  * `status` (string/enum, not null, default `pending`: `pending`, `authorized`, `paid`, `failed`)
  * `amount_cents` (integer, not null)
  * `timestamps`
* `create_payment_events`:
  * `payment_id` (foreign key, not null)
  * `gateway_event_id` (string, not null, unique index — garante idempotência do webhook)
  * `payload` (jsonb)
  * `processed_at` (datetime)
  * `timestamps`

### Testes

* Pagamento aprovado confirma o pedido
* Pagamento recusado não confirma o pedido nem baixa estoque
* Webhook duplicado (mesmo `gateway_event_id`) é ignorado na segunda vez — não duplica pedido, pagamento ou e-mail
* Nenhum teste ou log expõe dado sensível de cartão
* Teste end-to-end do fluxo completo: produto publicado → cliente navega no catálogo → adiciona ao carrinho → identifica-se → finaliza checkout → paga → pedido confirmado

### Critérios de aceite

* [x] Pagamento aprovado atualiza o pedido para `confirmed`
* [x] Pagamento recusado não confirma o pedido
* [x] Webhook duplicado é seguro (idempotente)
* [x] Nenhum dado sensível de cartão é persistido ou logado
* [x] **Fluxo completo Produto → Catálogo → Carrinho → Checkout → Pedido → Pagamento funciona ponta a ponta, testado**

### Decisões tomadas durante a implementação

* **Gateway simulado** (`Gateways::FakeGateway`), não um gateway real — o usuário optou por isso nesta fase por não ter credenciais de nenhum provedor ainda. A escolha do gateway real continua `TODO — DECISION REQUIRED` em `docs/payments.md`.
* Criação de pagamento idempotente por pedido (reaproveita um `Payment` `pending`/`authorized`/`paid` existente), mas uma tentativa recusada (`failed`) permite uma nova tentativa — sem isso o cliente nunca conseguiria tentar pagar de novo.
* Pagamento recusado deixa o pedido em `pending` (não cancela automaticamente) — cliente pode tentar de novo. Cancelamento automático/por timeout não está no escopo desta fase.
* Autenticação do webhook via segredo compartilhado simples (não é segurança real — não há dinheiro de verdade em jogo com um gateway fake), mas exercita genuinamente o requisito de "webhook autenticado".

### Achado de segurança

O endpoint de webhook (`PaymentWebhooksController`) inicialmente exigia token CSRF por herdar de `ApplicationController` — um gateway real nunca teria esse token. Os testes automatizados não pegaram isso porque o ambiente de teste desativa a proteção CSRF por padrão (`config.action_controller.allow_forgery_protection = false`). Corrigido com `skip_forgery_protection` no controller, e adicionado um teste que liga a proteção de propósito para evitar regressão.

### Dependências de outras fases

Fase 6.

---

# ✅ Marco: MVP concluído

Ao final da Fase 7, o sistema deve ser capaz de vender um produto simples do início ao fim. Nenhuma fase abaixo deve ser iniciada antes disso.

---

# PARTE 2 — Pós-MVP (funcionalidades avançadas)

As fases abaixo mantêm a mesma estrutura (objetivo, funcionalidades, modelos, migrations, testes, critérios de aceite, dependências) e devem ser detalhadas com a mesma profundidade da Parte 1 no momento em que forem iniciadas. Nesta primeira versão, ficam registradas em nível de escopo para orientar a sequência.

## FASE 8 — Estoque avançado

Status: `[x]`

### Objetivo

Suportar peça única e produto sob encomenda. "Pequena tiragem" já funcionava desde a Fase 1 (é só um produto `standard` com `stock_quantity > 1`, sem nenhuma mudança necessária). **Pré-venda (`pre_order`) foi adiada** — `docs/inventory.md` já marcava como `TODO — DECISION REQUIRED` (prazo máximo, política de cancelamento), decisão de negócio ainda não tomada.

### Funcionalidades

* `Product.availability_type`: `standard` (atual) | `one_of_a_kind` | `made_to_order`
* Peça única (`one_of_a_kind`): `stock_quantity` limitado a no máximo 1; uma vez `sold_out`, não pode voltar a `active` automaticamente (produto `standard` continua podendo ser reabastecido normalmente)
* Sob encomenda (`made_to_order`): disponibilidade não depende de `stock_quantity`; exige prazo de produção (`production_time_min_days`/`production_time_max_days`); checkout não debita estoque e grava snapshot do prazo apresentado no `OrderItem`

### Modelos envolvidos

* `Product` (novas colunas: `availability_type`, `production_time_min_days`, `production_time_max_days`)
* `OrderItem` (nova coluna: `production_time_snapshot`)

### Migrations necessárias

* `add_column :products, :availability_type, :string, null: false, default: "standard"` + índice
* `add_column :products, :production_time_min_days, :integer`
* `add_column :products, :production_time_max_days, :integer`
* `add_column :order_items, :production_time_snapshot, :string`

### Testes

* Model: `one_of_a_kind` rejeita `stock_quantity > 1`; `sold_out → active` rejeitado para `one_of_a_kind` mas permitido para `standard`; `made_to_order` exige prazo de produção válido (mínimo ≤ máximo); `available_for_purchase?` de `made_to_order` ignora estoque
* `Checkout::CreateOrder`: item `made_to_order` não debita estoque e grava snapshot do prazo; quantidade de `made_to_order` não é limitada por `stock_quantity`
* Admin: cadastro de cada tipo com os campos corretos

### Critérios de aceite

* [x] Peça única vendida não pode "voltar" a ficar disponível automaticamente
* [x] Produto sob encomenda é vendável sem depender de estoque físico
* [x] Prazo de produção é exibido ao cliente antes da compra e registrado no pedido
* [x] "Pequena tiragem" continua funcionando sem nenhuma mudança (regressão)

### Dependências de outras fases

Fase 7 (MVP concluído).

### Decisões tomadas durante a implementação

* `pre_order` explicitamente fora do escopo desta fase — pendente de decisão de negócio (prazo máximo de pré-venda, política de cancelamento). Ver `docs/inventory.md`.
* "Pequena tiragem" não ganhou nenhum campo/tipo novo — continua sendo `standard` com `stock_quantity` qualquer.

## FASE 9 — Variantes de produto

Status: `[x]`

### Objetivo

Suportar combinações comerciais reais (tamanho, cor, material) via `ProductVariant`, sem forçar variantes em produtos simples (ADR 001). Escopo decidido com o negócio: variantes só em produtos `standard`; cada variante tem preço próprio; eixos fixos (tamanho, cor, material) — sem sistema genérico de opções, sem preço/estoque compartilhado com o produto.

### Funcionalidades

* `ProductVariant`: SKU e estoque próprios (ADR 001), preço próprio (`price_cents`), eixos `size`/`color`/`material` (ao menos um obrigatório), flag `active` para descontinuar uma combinação sem apagar histórico.
* Um produto com variante nunca é comprado "cru" — `CartItem` exige `product_variant_id` quando `product.has_variants?`, e rejeita variante quando o produto não tem nenhuma.
* `Product#available_for_purchase?` para produto com variante passa a refletir se alguma variante ativa tem estoque, em vez do `stock_quantity` do próprio produto.
* `Product#availability_type` fica travado em `standard` enquanto o produto tiver variante cadastrada (não é possível virar `one_of_a_kind`/`made_to_order` com variantes existentes).
* Checkout revalida e bloqueia (`lock!`) produto e variante na mesma ordem estável já usada para produto sem variante; débito de estoque acontece na variante, não no produto.
* `OrderItem` grava snapshot da variante (SKU, tamanho, cor, material) — nunca reconstruído a partir da variante atual, que pode mudar ou ser desativada depois.
* Admin: CRUD de variantes aninhado em cada produto `standard`; exclusão é bloqueada (com mensagem) quando a variante já foi usada em algum pedido — nesse caso o cadastro orienta a desativar.
* Storefront: seletor de tamanho/cor/material na página do produto (Stimulus, client-side, sem round-trip ao servidor) — troca de combinação atualiza preço/estoque exibido e desabilita a compra quando a combinação não existe ou está sem estoque. Catálogo mostra "a partir de" + menor preço entre as variantes ativas.

### Modelos envolvidos

* `ProductVariant` (novo)
* `Product` (`has_many :product_variants`; `has_variants?`, `starting_price_cents`)
* `CartItem` (`product_variant` opcional, mas obrigatório quando o produto tem variantes; preço/subtotal usam a variante)
* `OrderItem` (snapshot: `product_variant`, `variant_sku`, `size_snapshot`, `color_snapshot`, `material_snapshot`)

### Migrations necessárias

* `create_table :product_variants` (`product_id`, `sku` único, `price_cents`, `stock_quantity`, `size`, `color`, `material`, `active`, checks `price_cents >= 0` e `stock_quantity >= 0`, índice único de combinação por produto via `COALESCE` — Postgres trata `NULL` como distinto de `NULL` em índice único comum)
* `add_reference :cart_items, :product_variant` + índice único `(cart_id, product_id, COALESCE(product_variant_id, 0))`, substituindo o antigo `(cart_id, product_id)`
* `add_reference :order_items, :product_variant` + colunas de snapshot (`variant_sku`, `size_snapshot`, `color_snapshot`, `material_snapshot`)

### Testes

* Model: `ProductVariant` (unicidade de SKU e de combinação, eixo obrigatório, preço/estoque não-negativos, só em produto `standard`); `Product` (`has_variants?`, `available_for_purchase?` e `starting_price_cents` com variante, `availability_type` travado); `CartItem` (variante obrigatória/proibida conforme o produto, variante pertence ao produto, preço/subtotal usam a variante, duas variantes do mesmo produto coexistem no carrinho)
* `Checkout::CreateOrder`: item com variante debita o estoque da variante e não do produto; snapshot gravado; falha quando a variante ficou sem estoque, foi desativada, ou o produto foi descontinuado mesmo com a variante disponível; snapshot preservado mesmo se a variante mudar depois; teste de concorrência dedicado para a última unidade de uma variante (mesma técnica do teste de concorrência do produto)
* Admin: CRUD de variante; exclusão bloqueada quando referenciada por um pedido
* Sistema (Capybara + Chrome headless): seleção de variante na PDP atualiza preço e adiciona a variante certa ao carrinho; combinação sem estoque desabilita o botão de compra

### Critérios de aceite

* [x] Produto sem variante continua funcionando exatamente como antes (regressão)
* [x] Produto com variante não pode ser comprado sem escolher uma
* [x] Duas compras simultâneas da última unidade da mesma variante — só uma vence
* [x] Pedido preserva snapshot da variante mesmo se ela for alterada/desativada depois

### Dependências de outras fases

Fase 8.

### Decisões tomadas durante a implementação

* Variante só é permitida em produto `availability_type: standard` — peça única e sob encomenda combinados com variante ficaram fora do escopo desta fase, decisão do negócio.
* Cada variante tem preço próprio (`price_cents`); não há preço único compartilhado com o produto.
* Eixos fixos (`size`/`color`/`material`) em vez de um sistema genérico de opções — sem necessidade concreta de outros eixos hoje.
* `Product#price_cents`/`stock_quantity` deixam de ser a fonte de verdade quando o produto tem variante — ficam presentes no schema (a coluna é `NOT NULL`), mas não são usados nas decisões de disponibilidade/preço nesse caso.

## FASE 10 — Personalização de produtos

Status: `[x]`

### Objetivo

Permitir que um produto defina campos de personalização em texto livre (gravação, mensagem, etc.), capturados no carrinho e preservados como snapshot imutável no pedido. Escopo decidido com o negócio: só texto livre (sem lista de opções fixas), sem sobretaxa de preço, independente de variante (Fase 9) e de `availability_type`.

### Funcionalidades

* `PersonalizationOption`: campo de texto por produto (`label` único por produto, `required`, `max_length`), disponível para qualquer produto — diferente de `ProductVariant`, não é restrito a `availability_type: standard`.
* Não cria estoque, SKU ou variação de preço — é só dado extra registrado no item. Pode coexistir livremente com variante no mesmo produto.
* `CartItem` armazena os valores submetidos (`personalizations`, JSONB) e valida contra as opções atuais do produto: rejeita campo que não pertence ao produto, campo obrigatório ausente e valor acima do `max_length` — nunca confia no que veio do formulário.
* Duas personalizações diferentes do mesmo produto (ex.: duas canecas gravadas com nomes diferentes) viram linhas separadas no carrinho; a mesma personalização soma quantidade — resolvido com `personalization_digest`, um fingerprint determinístico incluído no escopo de unicidade do `CartItem`, com índice único no banco (não só validação Rails).
* Checkout grava o snapshot (label + valor, já resolvidos) no `OrderItem` — self-contained, imune a mudança ou exclusão posterior da `PersonalizationOption`.
* Admin: CRUD de campos de personalização aninhado em cada produto. Diferente de `ProductVariant`, a exclusão nunca é bloqueada — não há FK do `OrderItem` para `PersonalizationOption` (o snapshot já é independente), então remover uma opção não afeta pedidos já feitos.
* Storefront: campos de texto na PDP (nos dois formulários de compra — produto simples e com variante), com `required`/`maxlength` do HTML já refletindo a opção; exibidos no carrinho, resumo do pedido e confirmação.

### Modelos envolvidos

* `PersonalizationOption` (novo)
* `Product` (`has_many :personalization_options`)
* `CartItem` (`personalizations` JSONB, `personalization_digest`)
* `OrderItem` (`personalizations` JSONB, snapshot self-contained)

### Migrations necessárias

* `create_table :personalization_options` (`product_id`, `label`, `required`, `max_length`, check `max_length > 0`, índice único `(product_id, label)`)
* `add_column :cart_items, :personalizations, :jsonb, default: []` + `add_column :cart_items, :personalization_digest, :string` (nunca nulo — mesmo sem personalização vira o digest de `[]`), substituindo o índice único de `(cart_id, product_id, COALESCE(product_variant_id, 0))` por um que também inclui `personalization_digest`
* `add_column :order_items, :personalizations, :jsonb, default: []`

### Testes

* Model: `PersonalizationOption` (label único por produto, `max_length` positivo); `CartItem` (campo obrigatório ausente, valor acima do limite, campo de outro produto rejeitado, valores em branco tratados como não preenchidos, duas personalizações diferentes coexistem, mesma personalização soma quantidade)
* `Checkout::CreateOrder`: snapshot (label + valor) gravado no pedido; snapshot preservado mesmo se a opção for renomeada ou excluída depois
* Admin: CRUD de campo de personalização; exclusão não é bloqueada mesmo já usada em pedido (sem FK)
* Sistema (Capybara + Chrome headless): preencher campo obrigatório até a confirmação do pedido preservando o valor; campo obrigatório vazio não adiciona ao carrinho

### Critérios de aceite

* [x] Produto sem personalização continua funcionando exatamente como antes (regressão)
* [x] Campo obrigatório não preenchido bloqueia a adição ao carrinho
* [x] Pedido preserva o texto exato digitado mesmo se a opção for editada/excluída depois
* [x] Duas personalizações diferentes do mesmo produto no carrinho não se fundem numa só linha

### Dependências de outras fases

Fase 9 (independente na prática — só depende da mesma área de código do `CartItem`).

### Decisões tomadas durante a implementação

* Só texto livre nesta fase — sem lista de opções fixas (ex.: dropdown de cor de linha). Sem necessidade concreta hoje.
* Personalização nunca afeta o preço — sem sobretaxa por campo.
* Independente de variante e de `availability_type` — um produto pode ter variante e personalização ao mesmo tempo, e personalização não exige `standard`.

## FASE 11 — Categorias, tags, materiais, técnicas, busca e filtros

Status: `[x]`

Objetivo: enriquecer a descoberta de produtos no catálogo (hoje o MVP só lista todos os produtos ativos).
Dependências: Fase 2.

### Implementação

* Categorias hierárquicas opcionais, com CRUD administrativo e associação a produtos.
* Tags, materiais e técnicas reutilizáveis, associados por tabelas de junção e editáveis no cadastro do produto por listas separadas por vírgula.
* Busca textual por nome e descrição (`q`) usando `ILIKE` do PostgreSQL.
* Filtros combináveis por categoria (incluindo descendentes), tag, material, técnica, disponibilidade, faixa de preço e personalização.
* Categorias desconhecidas retornam 404; produtos continuam sempre limitados ao status `active`.

## FASE 12 — Frete real

Status: `[x]`

Objetivo: substituir o frete fixo do MVP por cálculo real (CEP, peso, dimensões, transportadora) e rastreamento.
Dependências: Fase 7.

### Implementação

* `Shipping::Calculator` calcula o frete no servidor usando CEP, peso e quantidade, com limite de peso e prazo estimado por região.
* Produtos possuem peso e dimensões opcionais para cálculo e futura integração de cubagem.
* Pedidos preservam o resultado calculado e criam um `Shipment` inicial com transportadora, serviço, valor e prazo.
* CEP inválido ou peso acima do limite impedem o checkout sem criar pedido.
* O cálculo é isolado para permitir trocar o provedor interno por Correios, agregador ou transportadora privada após decisão de negócio.

## FASE 13 — Cupons e promoções

Status: `[x]`

### Objetivo

Descontos percentuais/fixos, com limite de uso e controle de concorrência. Decisões de negócio confirmadas antes da implementação (ver `docs/domain.md`): um cupom por pedido (não cumulativo), válido para a loja toda (sem restrição por produto/categoria), sem teto de desconto, valor mínimo de pedido opcional por cupom, limite de uso total global opcional (sem limite por cliente), validade por data opcional mais desativação manual.

### Funcionalidades

* **`Coupon`**: código único (normalizado em maiúsculas), tipo `percentage` ou `fixed` (um por cupom, nunca os dois), `minimum_subtotal_cents` opcional, `max_uses` opcional, `uses_count`, `starts_at`/`expires_at` opcionais, `active`. `valid_for?(subtotal_cents)` centraliza toda a regra de elegibilidade; `discount_cents_for(subtotal_cents)` nunca deixa o desconto ultrapassar o subtotal.
* **Carrinho**: aplicar/remover cupom (`POST /cart/apply_coupon`, `DELETE /cart/remove_coupon`) — `Cart belongs_to :coupon`, desconto mostrado no carrinho e no resumo do checkout.
* **Checkout**: `Checkout::CreateOrder` trava o cupom (`lock!`) na mesma transação do estoque, revalida contra o subtotal final, grava `discount_cents`/`coupon_id` no `Order` e incrementa `uses_count` — dois checkouts simultâneos não conseguem ultrapassar o `max_uses` de um cupom limitado.
* **Admin**: CRUD mínimo de cupons (`Admin::CouponsController`) incluído nesta fase (embora o dashboard administrativo completo seja Fase 14) — sem CRUD o cupom não teria como ser criado/operado.

### Modelos envolvidos

* `Coupon` (novo)
* `Cart` (`belongs_to :coupon`, `discount_cents`)
* `Order` (`belongs_to :coupon`, `discount_cents`)

### Migrations

* `create_table :coupons`
* `add_reference :carts, :coupon`
* `add_reference :orders, :coupon` + `add_column :orders, :discount_cents`

### Testes

* Model (Minitest): validações de `Coupon` (tipo/percentual/valor mutuamente exclusivos, código único), `valid_for?` e `discount_cents_for` cobrindo todos os edge cases (inativo, expirado, não iniciado, limite esgotado, abaixo do mínimo, desconto nunca negativo)
* Service (Minitest): `Checkout::CreateOrder` aplica cupom válido e incrementa `uses_count`; recusa cupom inválido/expirado/esgotado revalidado no momento do checkout; teste de concorrência real (threads) garantindo que duas finalizações simultâneas não ultrapassam `max_uses`
* Request (RSpec): aplicar/remover cupom no carrinho (válido, inválido, expirado); CRUD admin de cupons

### Critérios de aceite

* [x] Cupom percentual e cupom de valor fixo aplicam o desconto correto
* [x] Desconto nunca deixa o total do pedido negativo
* [x] Cupom expirado, inativo ou com uso esgotado é recusado tanto ao aplicar no carrinho quanto revalidado no checkout
* [x] Dois checkouts simultâneos usando o último uso disponível de um cupom limitado — só um consegue

### Dependências de outras fases

Fase 7.

## FASE 14 — Administração completa

Status: `[x]`

### Objetivo

Dashboard, gestão de clientes e autorização refinada — cupons (Fase 13) e moderação de avaliações (Fase 15) já existiam. Decisões de negócio confirmadas: um único papel de admin por enquanto (mas com checagem centralizada, preparando terreno para múltiplos papéis); dashboard com foco operacional (não métricas de receita); gestão de clientes só leitura (lista + detalhe com endereços e histórico de pedidos, sem editar/bloquear).

### Funcionalidades

* **Autorização centralizada**: `User#role` (enum, hoje só `admin`) + `Admin::BaseController#require_admin!` — único ponto que verifica o papel, nenhum controller faz a checagem sozinho. Resolve o `TODO — DECISION REQUIRED` de `docs/security.md` (decisão: implementação simples, sem gem dedicada, reavaliar se surgirem múltiplos papéis).
* **Dashboard** (`/admin`, raiz do namespace): pedidos pendentes, produtos com estoque baixo (`Product.low_stock`, limiar técnico de 3 unidades, só para `availability_type: standard`) e esgotados, reviews aguardando moderação.
* **Gestão de clientes**: `Admin::CustomersController` — lista com busca por nome/e-mail, detalhe com endereços e histórico de pedidos. Só leitura.
* **Navegação do admin**: layout próprio (`layouts/admin`) com barra de navegação compartilhada entre as páginas do admin (antes cada página era isolada, sem link entre si).

### Modelos envolvidos

* `User` (`role`)
* `Product` (scope `low_stock`, `LOW_STOCK_THRESHOLD`)

### Migrations

* `add_column :users, :role`

### Testes

* Model (Minitest): `User#admin?` default; `Product.low_stock` (inclui no limiar, exclui acima do limiar, exclui esgotado, exclui sob encomenda)
* Request (RSpec): dashboard exige admin e mostra as seções corretas; clientes lista/busca/detalhe exige admin

### Critérios de aceite

* [x] Um usuário não-autenticado não acessa nenhuma página do admin
* [x] Dashboard mostra pedidos pendentes, estoque baixo, esgotados e reviews pendentes
* [x] Admin consegue ver lista e detalhe de clientes, mas não editar nem bloquear

### Dependências de outras fases

Fase 7.

## FASE 15 — Wishlist, avaliações, galeria e relacionados

Status: `[x]`

### Objetivo

Wishlist e avaliações (reviews) do roadmap original, mais duas evoluções decididas junto: galeria de múltiplas imagens do produto (evolução da Fase 1) e "Você também pode gostar" (relacionados, novo — não estava no roadmap original). Decisões de negócio: reviews exigem aprovação do admin antes de publicar; qualquer cliente logado pode avaliar, com selo de compra verificada calculado automaticamente; relacionados são só "outros produtos ativos, mais recentes" (sem categoria/tag pra basear algo melhor); wishlist só para clientes logados.

### Funcionalidades

* **Galeria**: `Product has_many_attached :images` (além do `main_image`, que continua sendo a capa). Admin envia várias fotos por vez (somam, não substituem) e remove uma de cada vez. PDP mostra miniaturas que trocam a imagem principal (Stimulus, client-side).
* **Relacionados**: `Product#related_products` — outros produtos ativos, mais recentes, excluindo o atual. Reaproveita o `_product_card` do catálogo.
* **Wishlist**: `WishlistItem` (customer + product, único por par), só para clientes logados. Coração de favoritar no card e na PDP. Página "Meus favoritos" mostra produtos indisponíveis em vez de escondê-los (CLAUDE.md §35) e nunca é reserva de estoque. "Mover para o carrinho" só quando o produto não exige variante nem personalização obrigatória (`Product#directly_purchasable?`) — senão, leva para a PDP escolher.
* **Reviews**: `Review` (customer + product, único por par) com nota 1-5, comentário, `status` (pending/approved/rejected, default pending) e `verified_purchase` calculado (cliente tem pedido `confirmed` com o produto — ainda não existe status "entregue"). Só reviews `approved` aparecem na loja. Admin aprova/rejeita.

### Modelos envolvidos

* `WishlistItem` (novo)
* `Review` (novo)
* `Product` (`has_many_attached :images`; `related_products`, `approved_reviews`, `average_rating`, `reviews_count`, `directly_purchasable?`, `wishlist_items`, `reviews`)
* `Customer` (`wishlist_items`, `wishlist_products`, `reviews`)

### Migrations necessárias

* ActiveStorage já cobre a galeria (attachment novo, sem tabela própria)
* `create_table :wishlist_items` (`customer_id`, `product_id`, índice único do par)
* `create_table :reviews` (`customer_id`, `product_id`, `rating`, `comment`, `status`, `verified_purchase`, índice único do par, check `rating` entre 1 e 5)

### Testes

* Model: validações de `WishlistItem` e `Review` (unicidade, rating 1-5, `verified_purchase` calculado certo com pedido `confirmed`/`pending`); `Product` (`gallery_images`, `related_products`, `average_rating`/`reviews_count` só com aprovadas)
* Controller: upload/remoção de imagem (validado antes de anexar, já que `has_many_attached#attach` não passa pelas validações do model); favoritar/desfavoritar/mover para o carrinho; criar review (mass-assignment não permite setar `status`/`verified_purchase`); admin aprova/rejeita/filtra por status
* Sistema (Capybara + Chrome headless): troca de miniatura na galeria; favoritar na PDP → aparecer nos favoritos → mover pro carrinho; review enviada fica invisível até o admin aprovar

### Critérios de aceite

* [x] Produto sem galeria/variante/personalização continua funcionando como antes (regressão)
* [x] Review só aparece publicamente depois de aprovada pelo admin
* [x] Wishlist nunca reserva estoque; mostra produtos indisponíveis em vez de escondê-los
* [x] Relacionados nunca inclui o próprio produto nem produtos inativos

### Dependências de outras fases

Fases 2 e 4.

### Decisões tomadas durante a implementação

* Reviews exigem aprovação do admin antes de aparecer — moderação obrigatória, não automática.
* Qualquer cliente logado pode avaliar (não só quem comprou); `verified_purchase` é um selo calculado, não um requisito de acesso.
* Relacionados usam "mais recentes" por falta de categoria/tag (Fase 11) — reavaliar quando esse domínio existir.
* Wishlist não migra carrinho de convidado para conta — só funciona logado, desde o início.

## FASE 16 — SEO e conteúdo

Status: `[x]`

### Objetivo

Meta tags, Open Graph, sitemap e dados estruturados. Sem decisão de negócio envolvida — puramente técnico, já que slugs amigáveis (base de URL para SEO) já existiam desde o MVP.

### Funcionalidades

* **Meta tags**: `SeoHelper#page_title`/`page_description`/`canonical_url`, com fallback genérico do site (`DEFAULT_TITLE`/`DEFAULT_DESCRIPTION`) para páginas que não definem nada via `content_for`. PDP, catálogo (incluindo filtro por categoria e busca) definem título/descrição/canonical próprios.
* **Open Graph**: `og:title`, `og:description`, `og:url`, `og:type`, `og:image` (quando o produto tem `main_image`) no layout, alimentados pelos mesmos `content_for`.
* **Dados estruturados**: `SeoHelper#product_structured_data` gera JSON-LD `schema.org/Product` na PDP — nome, imagem (URL absoluta via `rails_blob_url`), SKU, `offers` (preço a partir de `starting_price_cents`, disponibilidade `InStock`/`OutOfStock`), `aggregateRating` quando há reviews aprovadas. Escapado com `json_escape` para não quebrar a tag `<script>` com dados do produto.
* **Sitemap** (`/sitemap.xml`): gerado dinamicamente via builder (sem gem), lista home, catálogo, categorias e produtos ativos (com `lastmod`). URLs absolutas resolvidas pelo host da requisição — não depende de decidir o domínio de produção agora (Fase 20).
* **`robots.txt`**: referencia o sitemap e desautoriza áreas não indexáveis (admin, carrinho, checkout, sessão, favoritos).

### Modelos envolvidos

Nenhum novo. Não foi criada coluna de meta description dedicada — derivada de `Product#description` truncada (CLAUDE.md §5: não adicionar campo sem necessidade de negócio clara).

### Migrations

Nenhuma.

### Testes

* Request (RSpec): título/descrição/canonical/OG da PDP e do catálogo (geral, por categoria, por busca); JSON-LD válido e com disponibilidade correta (`InStock`/`OutOfStock`); sitemap lista só produtos ativos (exclui draft/discontinued) e inclui home/catálogo/categorias

### Critérios de aceite

* [x] Toda página relevante (PDP, catálogo, home) tem `<title>` e meta description específicos, não o genérico
* [x] PDP tem Open Graph completo e JSON-LD `Product` válido
* [x] `/sitemap.xml` lista produtos ativos com URL absoluta e não vaza produtos draft/discontinued
* [x] `robots.txt` referencia o sitemap e bloqueia áreas administrativas/privadas

### Dependências de outras fases

Fase 2.

## FASE 17 — Performance

Status: `[~]`

### Objetivo

Revisão de N+1, índices, imagens, cache — sem otimização prematura, apenas com medição real. Cada item abaixo saiu de uma medição, não de leitura de código.

Dependências: Fase 7.

### Método

Requisições reais (`ActionDispatch::Integration::Session`) contra o catálogo de seed, contando `sql.active_record` por página, com warmup para não medir compilação de view.

**Achado de método, que mudou uma conclusão**: contar toda notificação superestima o problema — o query cache do Active Record serve repetições idênticas dentro da mesma requisição, e essas não são ida ao banco. A contagem passou a separar `payload[:cached]`. Foi isso que derrubou uma otimização já escrita (ver "Deliberadamente não feito").

Medir com o volume do seed também esconde o que importa: o custo das páginas não crescia com o catálogo, crescia com o **número de categorias**. Só a medição em escala mostrou o tamanho real.

### N+1 corrigidos

Queries (sem contar acertos de cache), com 23 categorias de topo:

| página | antes | depois |
| --- | --- | --- |
| home | 118 queries, 242 ms | 9 queries, 29 ms |
| catálogo | 40 queries, 60 ms | 17 queries, 41 ms |

* **Home — capa de categoria**: `cover_product_for` era uma busca por categoria, e cada uma arrastava anexo, blob e variant records atrás de si — 5 queries por categoria de topo. Agora são duas leituras fixas: um `DISTINCT ON (category_id)` escolhe as capas (o custo acompanha o número de categorias, não o tamanho do catálogo) e uma segunda leitura carrega as escolhidas já com o anexo, em lote.
* **Catálogo — breadcrumb do filtro lateral**: o filtro mostra o breadcrumb de cada categoria, e `Category#breadcrumb_name` sobe a árvore um nível por vez, uma query por nível, por categoria. `Category#self_and_descendant_ids` fazia o mesmo descendo. Introduzido `Category::Tree`, que carrega a árvore inteira em uma leitura e responde hierarquia em memória. A home usa a mesma árvore — a travessia manual que ela tinha era a mesma lógica duplicada.
* **`.load` antes de `any?`**: a view do catálogo pergunta `@products.any?` antes de renderizar a grade, e a PDP faz o mesmo com produtos relacionados e avaliações. Em relação não carregada isso é um `SELECT ... LIMIT 1` a mais por página, jogado fora logo em seguida. Três queries constantes removidas.

O método instância `Category#breadcrumb_name` continua existindo e em uso: a PDP e o admin renderizam uma categoria só, e para isso `includes(category: :parent)` já resolve. `Category::Tree` é para páginas que renderizam a árvore inteira.

### Deliberadamente não feito

* **Combinar as agregações de avaliação** (`average_rating` + `reviews_count`): a PDP pede as duas na marcação da página e o JSON-LD pede de novo — 6 chamadas. Chegou a ser implementado como uma leitura só, memoizada. A medição corrigida mostrou que o query cache já serve 4 das 6: o ganho real era **1 query**, ao custo de SQL cru (`pick(Arel.sql(...))`) e de uma memoização que envelhece no objeto. Revertido (§3, §51, §70).
* **Índices para as colunas de ordenação da vitrine** (`price_cents`, `name`): com o volume atual o plano é Seq Scan + Sort e o PostgreSQL ignoraria o índice. Reavaliar quando o catálogo crescer o suficiente para o plano mudar (§53).
* **Contadores materializados de avaliação** (counter cache + nota média em coluna): resolveria as agregações de vez, mas é mudança de schema mais callback (§57) sem necessidade medida.
* ~~**N+1 de `breadcrumb_name` no admin**~~ — medido e corrigido depois (ver "Painel do vendedor e admin" abaixo). A suposição de que era só o admin estava errada: o mesmo padrão existia no painel do vendedor, cujo tráfego cresce com o número de artesãos.

### Testes

Asserções sobre **crescimento**, nunca sobre um total absoluto — o total muda a cada alteração legítima de página, a inclinação é que não pode voltar. Helper compartilhado em `spec/support/query_helpers.rb`.

* RSpec: home e catálogo não emitem mais queries quando outra categoria é criada (ambos falham no código anterior — 13→33 e 13→15).
* RSpec: qual produto vira capa de categoria (o mais recente ativo da subárvore, ignorando os sem foto e os não ativos) — o comportamento não tinha teste nenhum antes do refactor.
* Minitest: `Category::Tree` responde breadcrumb e descendentes sem voltar ao banco.

Configuração: `spec/rails_helper.rb` passou a apontar `file_fixture_path` para `test/fixtures/files`, que as duas suítes compartilham, em vez de duplicar o PNG de exemplo.

### Critérios de aceite

* [x] Cada otimização saiu de uma medição, com antes e depois registrados
* [x] O custo da home e do catálogo não cresce com o número de categorias, com teste que falha no código anterior
* [x] Nenhum índice criado sem plano de consulta que o justifique
* [ ] Medição sob tráfego real em produção (depende de volume suficiente; primeira amostra abaixo)

### Primeira amostra em produção

Em 2026-08-31, os logs HTTP da Railway das 24 horas anteriores foram agregados sem healthchecks e sem expor IP, user agent ou requisições individuais. A amostra tinha apenas 20 requisições: 3 na home (p50 57 ms, p95 180 ms), nenhuma no catálogo e 20 no total fora de `/up`/`/ready` (p50 13 ms, p95 180 ms; 11 respostas 2xx e 9 respostas 3xx). Esse volume não permite concluir a medição da fase, especialmente porque o catálogo não recebeu tráfego. A medição deve ser repetida quando houver tráfego orgânico suficiente; não gerar carga artificial em produção para fechar o critério.

## FASE 18 — Segurança (revisão aprofundada)

Status: `[x]`

### Objetivo

Revisão formal de autenticação, autorização, uploads, rate limiting, dados sensíveis — além do que já foi validado incrementalmente em cada fase do MVP. Achados classificados por severidade (CRITICAL/HIGH/MEDIUM/LOW) e corrigidos os que faziam sentido agora (nenhum CRITICAL/HIGH encontrado).

### Achados e correções (MÉDIO)

* **Cookies sem `secure`**: `session_id`, `customer_session_id`, `cart_token` agora marcam `secure: Rails.env.production?`.
* **Sem HTTPS forçado**: `config.force_ssl = true` em produção (HSTS + cookies secure), independente do domínio final (decisão da Fase 20). `config.assume_ssl` fica para a Fase 20 (depende do proxy SSL escolhido).
* **CSP não configurada**: política estrita (`default-src 'self'`) — a aplicação não carrega nada externo (importmap vendoriza JS localmente, Tailwind é um CSS local único). Nonce por requisição para o script inline do importmap.
* **Cupom sem rate limit**: dava pra adivinhar código válido por força bruta. `rate_limit` adicionado em `apply_coupon`.
* **Sessão nunca expira**: cookie era `permanent` (20 anos) sem expiração no servidor. `Session`/`CustomerSession` agora expiram por inatividade (7 dias admin, 30 dias cliente — área menos sensível), renovada a cada requisição autenticada.

### Achados e correções (BAIXO)

* Checkout (`POST /orders`) sem rate limit — adicionado.
* `docs/security.md` tinha dois TODOs desatualizados (limite de upload já resolvido na Fase 1; rate limiting/headers agora resolvidos aqui) — documentação atualizada.

### Infraestrutura de teste

`rate_limit` (Rails 8 nativo) depende de `Rails.cache`, e o ambiente de teste usava `:null_store` — o que tornava rate limiting **impossível de testar de verdade** (contador nunca persiste). Trocado para `:memory_store` em teste, com o cache limpo a cada exemplo/teste (RSpec e Minitest) para não vazar contagem entre eles.

### Já estava sólido, sem necessidade de mudança

Autorização centralizada (Fase 14), CSRF (única exceção documentada é o webhook, com segredo verificado por comparação timing-safe), nenhum `permit!`/mass assignment solto, mensagens de login sem enumeração de usuário (`authenticate_by`), parâmetros sensíveis filtrados do log, upload de imagem já validava conteúdo real via Marcel (não só o header declarado pelo cliente).

### Testes

* Model (Minitest): `Session.active`/`CustomerSession.active` (dentro e fora da janela de inatividade)
* Request (RSpec): sessão expira/permanece válida conforme o tempo passado (`travel`); rate limit de cupom e de checkout; CSP presente com nonce não vazio

### Critérios de aceite

* [x] Nenhum achado CRITICAL ou HIGH
* [x] Cookies de sessão/carrinho marcados `secure` em produção
* [x] HTTPS forçado e CSP estrita configuradas para produção
* [x] Endpoints sensíveis a força bruta (login, cupom, checkout) têm rate limit
* [x] Sessão expira por inatividade, tanto admin quanto cliente
* [x] `docs/security.md` sem TODOs desatualizados

### Dependências de outras fases

Fase 7.

## FASE 19 — Observabilidade

Status: `[~]`

Dependências: Fase 7.

### Implementação local

* Eventos estruturados nativos do Rails 8.1 serializados como JSON de uma linha para o Log Explorer da Railway, sem nova gem ou fornecedor de APM.
* Requests registram status, duração, tempo de view/banco, queries e `request_id`; Active Job registra classe, fila, duração, retry e falha sem argumentos potencialmente pessoais.
* Erros registram classe, origem, severidade e backtrace limitado, sem mensagem ou contexto arbitrário que possa conter entrada do cliente.
* Eventos explícitos para pedido criado, tentativa de pagamento criada e webhook aplicado, somente com IDs internos, centavos, gateway e status.
* `/ready` valida o banco primário e devolve 503 genérico em falha; `/up` permanece como liveness. `.railway/railway.ts` passa a usar `/ready` no deploy.
* Runbook e filtros do Log Explorer documentados em `docs/architecture.md`, seção "Observabilidade".

### Critérios de aceite

* [x] Eventos estruturados não quebram o fluxo mesmo se a saída falhar
* [x] Request, job, erro, checkout e pagamento têm sinais pesquisáveis sem dados pessoais
* [x] Readiness diferencia processo vivo de banco disponível
* [x] Testes cobrem serialização, privacidade, correlação e falha do banco
* [x] Código implantado, IaC sem drift e `/ready` validado na Railway
* [x] Evento estruturado confirmado no Log Explorer com status, duração, tempos de banco/view, queries e `request_id`
* [x] Dashboard/alertas operacionais configurados no canal escolhido pelo negócio
* [ ] Medição da Fase 17 realizada sob tráfego real

### Configuração operacional em produção

Em 2026-08-31, o dashboard do ambiente `production` foi criado na Railway com blocos de disco, rede, memória, CPU, logs de erro e uso/custo. O app Slack `EloShop Railway Alerts` publica no canal `#novo-canal`; a regra do projeto recebe falha, crash e OOM de deployment, alerta de volume e eventos de monitor, sem ambientes efêmeros de PR. A URL do webhook não foi versionada nem registrada na documentação.

Os monitores de threshold de CPU/RAM não foram criados: a interface da conta atual não oferece `Add monitor` (recurso do plano Pro). A regra Slack já inclui `Monitor Triggered`, portanto esses eventos serão encaminhados quando o plano/recurso estiver disponível. Não iniciar upgrade pago sem decisão explícita do negócio.

## FASE 20 — Produção e deploy

Status: `[~]`

Dependências: Fase 7 (mínimo); recomendável após Fases 12 e 18.

### Decisões de negócio confirmadas

Hospedagem: Railway (PaaS). Domínio: nenhum ainda — usa o subdomínio `*.up.railway.app` atribuído automaticamente. Gateway de pagamento real: Mercado Pago.

### Etapa A — Infraestrutura de deploy na Railway

Status: `[x]`

Objetivo: colocar a aplicação no ar na Railway, mantendo `Gateways::FakeGateway` por enquanto — separa "infra funcionando" de "processar dinheiro de verdade" (Etapa B).

**Implementação** — ver `docs/architecture.md`, seção "Deploy", para o runbook completo (variáveis de ambiente, volume, etc.):

* Kamal (`config/deploy.yml`) fica parado no repositório, sem uso — deploy real é via Dockerfile + Railway.
* `railway.json` aponta o healthcheck pra `/up` e o builder pro Dockerfile existente.
* `config/database.yml`: produção parseia `DATABASE_URL` (único Postgres da Railway) e monta 4 bancos distintos (`<nome>`, `_cache`, `_queue`, `_cable`) dentro da mesma instância — **achado real durante a implementação**: `url:` sempre vence sobre um `database:` explícito no mesmo hash, então reaproveitar a mesma `DATABASE_URL` inteira nos 4 papéis faz `db:prepare` carregar só o schema do `primary`, deixando cache/queue/cable sem nenhuma tabela. Confirmado com um Postgres local antes de decidir a correção, e coberto por teste (`test/config/database_yml_test.rb`) que não depende de banco de verdade.
* `config/storage.yml`: serviço `production` aponta pro volume persistente da Railway (`RAILS_STORAGE_PATH`) — sem isso, imagens de produto seriam perdidas a cada redeploy.
* `config.assume_ssl = true` em produção (Railway termina TLS na borda e encaminha HTTP puro pro container).
* `bin/docker-entrypoint`: repassa a porta dinâmica da Railway (`$PORT`) pro Thruster (`HTTP_PORT`), que por padrão só escuta na 80.
* Deploy automático: o serviço está conectado ao repo/branch `main` no GitHub (antes os deploys eram uploads do diretório local via `railway up`, sem garantia de corresponder ao versionado). **Achado real**: o "Wait for CI" só tem valor com CI funcionando, e `.github/workflows/ci.yml` estava inválido — `DATABASE_URL: ******localhost:5432` (sobra de uma redação de segredo) faz o YAML tentar ler um alias e derruba o parse do arquivo inteiro, então nenhum job rodava no `main` havia vários commits, com o CodeQL verde mascarando o problema.
* **Achado real corrigido**: `rswag-api`/`rswag-ui` estavam no grupo `development, test` do `Gemfile`, mas são montadas em `/api-docs` em todos os ambientes — o boot de produção quebrava (`uninitialized constant Rswag`). Movidas pra fora do grupo.

**Testes**: `test/config/database_yml_test.rb` (resolução da config de 4 bancos a partir de uma `DATABASE_URL` fake, sem precisar de Postgres de verdade). Validado manualmente end-to-end contra um Postgres local: `db:prepare`, `assets:precompile` e boot em modo produção, todos com sucesso.

**Critérios de aceite**

* [x] `db:prepare` cria e migra os 4 bancos corretamente a partir de uma única `DATABASE_URL`
* [x] Boot em modo produção não quebra (achado do Rswag corrigido)
* [x] `assets:precompile` funciona sem `RAILS_MASTER_KEY` (`SECRET_KEY_BASE_DUMMY`, igual ao build do Dockerfile)
* [x] Deploy real na Railway confirmado ao vivo (`eloshop-web-production.up.railway.app`, deploy `SUCCESS`/`RUNNING`)
* [x] Push no `main` dispara o deploy automaticamente, com "Wait for CI" ligado (a Railway só builda depois dos check suites do GitHub passarem) — ver `docs/architecture.md`, "Deploy automático a partir do GitHub"

### Etapa B — Mercado Pago real (PIX)

Status: `[~]`

Objetivo: substituir `Gateways::FakeGateway` por um adapter real do Mercado Pago, começando só por PIX (sem cartão/boleto — evita lidar com dado sensível de cartão e SDK de tokenização no front nesta primeira volta). Ver `docs/payments.md`.

## FASE 21 — Pós-lançamento

Dependências: Fase 20.

---

# PARTE 3 — Marketplace (ADR 004)

Mudança de conceito confirmada pelo negócio: o sistema deixa de ser uma loja única e passa a ser um marketplace onde múltiplos artesãos vendem suas próprias peças. Ver `docs/decisions/004-marketplace-model.md`, `CLAUDE.md` §34 e `docs/architecture.md` (seção "Multi-tenancy / marketplace") para o contexto completo e as implicações estruturais.

As decisões de negócio do ADR 004 foram respondidas: repasse automático; aprovação/KYC obrigatórios antes da publicação; nota fiscal/impostos sob responsabilidade do vendedor; cancelamentos, reembolsos e disputas sob decisão da plataforma. A estrutura é `Order` principal + `SellerOrder`; no primeiro lançamento há exatamente um vendedor por checkout. A comissão é 15% dos produtos após descontos, sem frete. Multi-vendedor depende de acesso comercial ao split 1:N do Mercado Pago.

## FASE 22 — Vendedores (Artesãos): fundação do marketplace

Status: `[~]`

### Objetivo

Introduzir `Seller` como entidade comercial independente e vincular `Product` a um vendedor, com painel administrativo escopado ao próprio catálogo/estoque/pedidos.

### Funcionalidades

* `Seller`: cadastro, autenticação própria (papel distinto do admin de plataforma — estende a autorização centralizada introduzida na Fase 14, `User#role`/`Admin::BaseController`, com um novo papel `seller` ou identidade própria, a decidir na implementação)
* `Product` passa a `belongs_to :seller`; unicidade de `sku`/`slug`, hoje global, passa a ser escopada por vendedor
* Painel do vendedor: CRUD do próprio catálogo, visão do próprio estoque e dos próprios pedidos — nunca acesso a dados de outro vendedor
* Painel de plataforma: aprovação/gestão de vendedores (distinto do painel de vendedor)

### Modelos envolvidos

* `Seller` (novo)
* `Product` (`belongs_to :seller`)

### Migrations necessárias

* `create_table :sellers`
* `add_reference :products, :seller` (backfill necessário para produtos já existentes — decisão de negócio: vendedor padrão/migração dos produtos atuais)
* Ajustar índices únicos de `sku`/`slug` em `products` para escopo `(seller_id, sku)`/`(seller_id, slug)`

### Testes

* Model: `Product` só pertence a um `Seller`; unicidade de `sku`/`slug` escopada, não mais global
* Autorização: vendedor não acessa produtos/pedidos de outro vendedor alterando a URL; painel de plataforma continua restrito ao admin

### Critérios de aceite

* [x] Todo produto pertence a um vendedor
* [x] `sku`/`slug` únicos por vendedor, não mais globalmente
* [x] Vendedor não consegue acessar catálogo/pedidos de outro vendedor
* [x] Testes cobrindo os pontos acima passando

### Dependências de outras fases

Fase 14 (estende a autorização centralizada já existente).

## FASE 23 — Split de pedidos, pagamento e frete por vendedor

Status: `[x]`

### Objetivo

Introduzir `SellerOrder` como a unidade comercial/operacional do vendedor. O primeiro lançamento aceita um vendedor por checkout; a evolução para vários `SellerOrder`s em uma compra única divide frete/fulfillment e pagamento por vendedor e depende de acesso ao split 1:N.

### Funcionalidades

* Primeiro lançamento: checkout aceita apenas itens de um vendedor e gera um `Order` principal com exatamente um `SellerOrder`
* Evolução condicionada: itens de vendedores diferentes geram um `SellerOrder` por vendedor somente depois da habilitação comercial do split 1:N
* `SellerOrder`: preserva vendedor, totais, status e responsabilidades operacionais da parte do pedido
* `Shipment`: passa de `has_one` por `Order` para um por `SellerOrder`
* `Payment`: split com comissão da plataforma de 15% sobre produtos após descontos, sem frete; tarifa do Mercado Pago separada e reversão proporcional em reembolso

### Modelos envolvidos

* `Order`, `SellerOrder`, `OrderItem` (atribuição do item ao subpedido do vendedor)
* `Shipment` (um por `SellerOrder`)
* `Payment` (split/comissão)

### Migrations necessárias

A definir na implementação, preservando a estrutura decidida de `Order` principal + `SellerOrder` por vendedor e o backfill seguro dos pedidos existentes.

### Testes

* Checkout: carrinho de um vendedor gera exatamente um `SellerOrder`; carrinho multi-vendedor continua bloqueado até a habilitação do split 1:N
* Concorrência: mesma cobertura já exigida para estoque/pedido único (Fase 5) aplicada por vendedor
* Pagamento: split calcula 15% sobre produtos após descontos, exclui frete, separa a tarifa do gateway e reverte a comissão proporcionalmente

### Critérios de aceite

* [x] Pedido de vendedor único cria exatamente um `SellerOrder`, com itens e frete próprios; multi-vendedor permanece bloqueado até o split 1:N
* [x] Comissão de 15% é calculada e registrada em centavos sobre produtos após descontos, sem frete, com tarifa separada e reversão proporcional
* [x] Nenhuma regressão no fluxo de pedido de vendedor único (Fases 5–13)

### Dependências de outras fases

Fase 22.

---

# Regras do Roadmap

## 1. Uma fase por vez

Não implemente várias fases simultaneamente sem necessidade.

## 2. MVP antes de avançado

Nenhuma fase da Parte 2 deve ser iniciada antes da Fase 7 (fim do MVP) estar concluída, testada e revisada.

## 3. Não pule testes

Uma fase não está concluída somente porque a funcionalidade "funciona".

## 4. Critérios de aceite são obrigatórios

Uma tarefa somente pode ser marcada como `[x]` quando seus critérios de aceite forem atendidos.

## 5. Mudanças no roadmap

Mudanças significativas devem ser discutidas antes da implementação.

## 6. Descobertas durante implementação

Se uma tarefa revelar uma nova necessidade:

```text
Não esconda a mudança.
Não altere silenciosamente o escopo.
Documente a descoberta.
Proponha alteração no roadmap.
```

## 7. Débito técnico

Quando algo precisar ser deixado para depois:

```text
TODO:
Descrição
Motivo
Impacto
Prioridade
```

Não esconda débito técnico.

---

# Definition of Done

Uma tarefa é considerada concluída somente quando:

* [ ] Código implementado
* [ ] Testes implementados
* [ ] Testes passando
* [ ] Lint passando
* [ ] Segurança revisada
* [ ] Edge cases considerados
* [ ] Diff revisado
* [ ] Documentação atualizada quando necessário
* [ ] Critérios de aceite atendidos
* [ ] Roadmap atualizado

---

# Estado atual

Fase atual:

`🔄 FASE 17 — Performance em andamento; FASE 19 — Observabilidade em andamento (código, dashboard e alertas Slack validados; medição sob tráfego real pendente); FASE 20 — Produção e deploy em andamento (Etapa A concluída, Etapa B parcial); FASE 22 — Fundação do marketplace em andamento; FASE 23 — Split de pedidos, pagamento e frete por vendedor concluída no código.

FASE 22 iniciada: `Seller` e o papel `seller` foram introduzidos; produtos legados receberam o vendedor aprovado EloShop; `Product` agora pertence obrigatoriamente ao vendedor com `sku`/`slug` únicos por vendedor; cadastro pendente, aprovação/suspensão pela plataforma, painel escopado, URL pública por artesão e bloqueio de carrinho multi-vendedor foram implementados. O painel do vendedor usa somente `Current.user.seller`, e testes de alteração de ID cobrem o isolamento. O painel recebeu uma home editorial responsiva com busca escopada ao catálogo, métricas, produtos e pedidos recentes, atalhos operacionais e status financeiro; variantes, personalizações e galeria também são gerenciadas pelo vendedor. O onboarding financeiro foi definido e implementado com OAuth Authorization Code do Mercado Pago: o provedor realiza o KYC 6, a EloShop não coleta documentos, tokens ficam cifrados e a plataforma confirma explicitamente o KYC antes de aprovar. O modo sandbox opt-in envia `test_token=true`, identifica o ambiente no painel e mantém contas de teste inelegíveis para aprovação. Falta configurar as credenciais de uma aplicação Marketplace de testes e validar o fluxo ponta a ponta; `SellerOrder` e split pertencem à Fase 23.

FASE 23 concluída no código: checkout de um vendedor cria atomicamente um `SellerOrder`; itens e frete pertencem a essa unidade operacional. A cobrança PIX usa o token OAuth renovável do artesão e envia `application_fee` de 15% sobre produtos após descontos, excluindo frete; a tarifa do Mercado Pago é registrada separadamente. Reembolsos parciais/totais são exclusivos do admin, idempotentes, auditados e revertem a comissão proporcionalmente. O painel do vendedor mostra apenas seus `SellerOrder`s e valores. O backfill aborta diante de pedidos legados multi-vendedor. Multi-vendedor continua bloqueado até acesso comercial ao split 1:N. Pipeline local verde: 253 RSpec, 394 Minitest, 13 system tests, lint e segurança. A validação ponta a ponta no sandbox continua pendente como dependência externa das Fases 20/22, não como liberação para 1:N.

FASE 19 — Observabilidade implantada e validada na Railway com `Rails.event`: requests, jobs e erros em JSON pesquisável; eventos seguros de checkout/pagamento; correlação por request_id; e `/ready` validando o banco primário. `railway config plan` está sem drift, `/ready` respondeu 200 publicamente e o Log Explorer devolveu evento real com duração, tempos de banco/view, queries e request_id. O dashboard operacional e o webhook Slack para `#novo-canal` estão configurados. Monitores de threshold de CPU/RAM dependem do plano Pro e não estão disponíveis na conta atual; a regra já aceita futuros eventos `Monitor Triggered`. Falta coletar tráfego suficiente para a medição da Fase 17. Detalhes em docs/architecture.md, seção "Observabilidade".

FASE 20, Etapa A (infraestrutura de deploy) CONCLUÍDA: a aplicação está no ar em eloshop-web-production.up.railway.app e o push no main dispara o deploy automaticamente, com "Wait for CI" ligado (a Railway só builda depois dos check suites do GitHub passarem) — ver docs/architecture.md, seções "Deploy" e "Deploy automático a partir do GitHub". Três achados reais corrigidos: rswag-api/ui quebrava o boot de produção (gem no grupo errado); compartilhar a mesma DATABASE_URL entre os 4 papéis do banco (primary/cache/queue/cable) fazia db:prepare pular o schema de três deles; e .github/workflows/ci.yml estava inválido (um * no valor de DATABASE_URL derrubava o parse do YAML), de modo que NENHUM job de CI rodava no main havia vários commits — o CodeQL, em outro workflow, seguia verde e mascarava.

FASE 20, Etapa B (Mercado Pago real via PIX) INICIADA e parcial: o adapter `Gateways::MercadoPago` existe e só é selecionado com `PAYMENT_GATEWAY=mercado_pago`; em produção, configuração ausente ou gateway fake falha explicitamente. As três lacunas locais foram fechadas: PIX vencido gera nova tentativa, cada tentativa persiste uma chave de idempotência própria (inclusive através de timeout/retry), e a página acompanha a confirmação do webhook automaticamente sem criar cobranças no polling. A integração NUNCA rodou contra o sandbox (falta credencial); os testes stubam HTTP e cobrem o contrato do adapter, não a API real. Detalhes em `docs/payments.md`.

FASE 17 — Performance em andamento, com medição real (ver a seção da fase): N+1 da home, do catálogo, dos formulários do admin e do formulário de produto do painel do vendedor eliminados — com 23 categorias de topo, a home caiu de 118 para 9 queries e o catálogo de 40 para 17. Achado de método registrado: contar toda notificação de `sql.active_record` superestima o problema, porque o query cache do Active Record serve repetições dentro da mesma requisição — isso derrubou uma otimização já escrita, que foi revertida. A medição do admin (2026-09-01) desmentiu a suposição registrada em "deliberadamente não feito": o alvo apontado era o menos afetado, e o custo real estava nos formulários — inclusive no do painel do vendedor, cujo tráfego cresce com o número de artesãos. Corrigido com `Category::Tree`, zerando o crescimento nas três páginas. A primeira amostra de 24 horas em produção teve apenas 20 requisições fora dos healthchecks (3 na home e nenhuma no catálogo), insuficiente para concluir a fase — a medição sob tráfego real segue sendo o único critério em aberto.

INFRAESTRUTURA DE CI corrigida: a suíte Minitest (343 runs, 952 asserções — models, services, integração) NÃO rodava em CI nenhum. Nem no job `test` do `.github/workflows/ci.yml` (só `bundle exec rspec`), nem no `bin/ci`, nem no hook de pre-commit. Toda a camada de domínio, onde o CLAUDE.md manda pôr regra de negócio, seguia sem verificação em push ou PR. Agora roda como job `minitest` separado do `test` (uma falha não mascara a outra) e como etapa do `bin/ci`. Com "Wait for CI" ligado, uma falha do Minitest passa a bloquear deploy — que é a intenção. Achado colateral, pré-existente e só local: a etapa "Tests: Seeds" do `bin/ci` usava `db:seed:replant`, cujo TRUNCATE pega ACCESS EXCLUSIVE e entrava em deadlock contra conexão remanescente do banco de teste (observado em 2 de 3 execuções, como deadlock e como violação de FK sobre linha de fixture sobrevivente) — trocado por `db:test:prepare db:seed`, mais um `db:test:prepare` final que devolve o banco vazio, porque o seed deixado para trás fazia a rodada seguinte da suíte falhar sozinha. Três execuções seguidas de `bin/ci` verdes depois da mudança.

FASE 18 — Segurança concluída (nenhum achado CRITICAL/HIGH). FASE 15 foi implementada anteriormente fora de ordem a pedido do negócio. Pré-venda (pre_order, Fase 8) segue adiada — decisão de negócio pendente, ver docs/inventory.md. Mudança de conceito confirmada pelo negócio: o projeto é um marketplace (múltiplos artesãos vendendo suas próprias peças), formalizada no ADR 004 e em implementação nas Fases 22 e 23.`

Próxima tarefa:

`Criar/configurar uma aplicação Marketplace de testes, registrar a callback /painel/mercado-pago/callback, substituir temporariamente MERCADO_PAGO_MARKETPLACE_APP_ID/MERCADO_PAGO_MARKETPLACE_CLIENT_SECRET pelas credenciais dessa aplicação, definir MERCADO_PAGO_MARKETPLACE_SANDBOX=true e validar o OAuth com uma conta TESTUSER Vendedor. Depois da validação, restaurar as credenciais produtivas e remover o modo sandbox. Em paralelo, a medição da Fase 17 continua aguardando tráfego orgânico suficiente e o teste PIX sandbox continua pendente.`

Última atualização:

`2026-09-01`
