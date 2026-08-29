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

Status: `[ ]`

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

### Critérios de aceite

* [ ] Aplicação Rails criada
* [ ] PostgreSQL configurado e acessível localmente
* [ ] Docker configurado
* [ ] Git e `.gitignore` configurados
* [ ] Variáveis de ambiente e Rails Credentials configurados
* [ ] Tailwind e Hotwire instalados
* [ ] Minitest e Capybara configurados
* [ ] Lint configurado
* [ ] CI configurado e executando
* [ ] Aplicação inicia localmente sem erros

### Dependências de outras fases

Nenhuma.

---

## FASE 1 — Produto

Status: `[ ]`

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

* [ ] Administrador consegue autenticar
* [ ] Administrador consegue criar, editar, publicar e despublicar um produto
* [ ] Administrador consegue anexar imagem principal
* [ ] `slug` e `sku` são únicos e validados também no banco (unique index)
* [ ] Usuário não autenticado não acessa nenhuma rota administrativa, mesmo alterando a URL diretamente

### Dependências de outras fases

Fase 0.

---

## FASE 2 — Catálogo (storefront de listagem)

Status: `[ ]`

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

* [ ] Cliente acessa a listagem de produtos publicados
* [ ] Cliente acessa a página de um produto por URL amigável (`/produtos/:slug`)
* [ ] Produto esgotado é claramente identificado como indisponível
* [ ] Produto não publicado é inacessível para o público

### Dependências de outras fases

Fase 1.

---

## FASE 3 — Carrinho

Status: `[ ]`

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

* [ ] Cliente consegue adicionar, remover e alterar quantidade de itens
* [ ] Total exibido é sempre calculado no servidor, nunca confiado do client
* [ ] Produto indisponível não pode ser adicionado ao carrinho
* [ ] Carrinho persiste entre requisições da mesma sessão

### Dependências de outras fases

Fases 1 e 2.

---

## FASE 4 — Identificação do cliente e endereço

Status: `[ ]`

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

* [ ] Cliente consegue criar conta e autenticar
* [ ] Cliente consegue cadastrar um endereço de entrega
* [ ] Carrinho existente na sessão é associado ao cliente após identificação
* [ ] Cliente não identificado não avança para o checkout

### Dependências de outras fases

Fase 3.

---

## FASE 5 — Checkout

Status: `[ ]`

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

* [ ] Pedido é criado somente com valores recalculados no servidor
* [ ] Estoque é debitado de forma atômica, sem venda além do disponível
* [ ] Pedido preserva snapshot de produto e endereço
* [ ] Checkout é idempotente
* [ ] Falha em qualquer etapa não deixa pedido nem estoque em estado inconsistente

### Dependências de outras fases

Fase 4.

---

## FASE 6 — Pedido (ciclo de vida mínimo)

Status: `[ ]`

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

* [ ] Cliente consegue visualizar o status e os itens do próprio pedido
* [ ] Cliente não consegue acessar pedido de outro cliente alterando a URL
* [ ] Administrador consegue listar e visualizar pedidos
* [ ] Transições de estado inválidas são bloqueadas

### Dependências de outras fases

Fase 5.

---

## FASE 7 — Pagamento

Status: `[ ]`

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

* [ ] Pagamento aprovado atualiza o pedido para `confirmed`
* [ ] Pagamento recusado não confirma o pedido
* [ ] Webhook duplicado é seguro (idempotente)
* [ ] Nenhum dado sensível de cartão é persistido ou logado
* [ ] **Fluxo completo Produto → Catálogo → Carrinho → Checkout → Pedido → Pagamento funciona ponta a ponta, testado**

### Dependências de outras fases

Fase 6.

---

# ✅ Marco: MVP concluído

Ao final da Fase 7, o sistema deve ser capaz de vender um produto simples do início ao fim. Nenhuma fase abaixo deve ser iniciada antes disso.

---

# PARTE 2 — Pós-MVP (funcionalidades avançadas)

As fases abaixo mantêm a mesma estrutura (objetivo, funcionalidades, modelos, migrations, testes, critérios de aceite, dependências) e devem ser detalhadas com a mesma profundidade da Parte 1 no momento em que forem iniciadas. Nesta primeira versão, ficam registradas em nível de escopo para orientar a sequência.

## FASE 8 — Estoque avançado

Objetivo: suportar peça única, pequena tiragem, produto sob encomenda e pré-venda (hoje o MVP só suporta estoque numérico padrão).
Dependências: Fase 7.

## FASE 9 — Variantes de produto

Objetivo: suportar combinações comerciais reais (tamanho, cor, material) via `ProductVariant`, sem forçar variantes em produtos simples.
Dependências: Fase 8.

## FASE 10 — Personalização de produtos

Objetivo: permitir personalização (gravação, cor, mensagem) com snapshot da escolha no pedido.
Dependências: Fase 9.

## FASE 11 — Categorias, tags, materiais, técnicas, busca e filtros

Objetivo: enriquecer a descoberta de produtos no catálogo (hoje o MVP só lista todos os produtos ativos).
Dependências: Fase 2.

## FASE 12 — Frete real

Objetivo: substituir o frete fixo do MVP por cálculo real (CEP, peso, dimensões, transportadora) e rastreamento.
Dependências: Fase 7.

## FASE 13 — Cupons e promoções

Objetivo: descontos percentuais/fixos, com limite de uso e controle de concorrência.
Dependências: Fase 7.

## FASE 14 — Administração completa

Objetivo: dashboard, gestão de clientes, cupons, avaliações e autorização refinada (o MVP só cobre CRUD básico de produto e listagem de pedidos).
Dependências: Fase 7.

## FASE 15 — Wishlist e avaliações

Dependências: Fases 2 e 4.

## FASE 16 — SEO e conteúdo

Objetivo: meta tags, Open Graph, sitemap, dados estruturados.
Dependências: Fase 2.

## FASE 17 — Performance

Objetivo: revisão de N+1, índices, imagens, cache — sem otimização prematura, apenas com medição real após o MVP em uso.
Dependências: Fase 7.

## FASE 18 — Segurança (revisão aprofundada)

Objetivo: revisão formal de autenticação, autorização, uploads, rate limiting, dados sensíveis — além do que já foi validado incrementalmente em cada fase do MVP.
Dependências: Fase 7.

## FASE 19 — Observabilidade

Dependências: Fase 7.

## FASE 20 — Produção e deploy

Dependências: Fase 7 (mínimo); recomendável após Fases 12 e 18.

## FASE 21 — Pós-lançamento

Dependências: Fase 20.

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

`FASE 0 — Fundação técnica`

Próxima tarefa:

`Criar a aplicação Rails e configurar a base do projeto.`

Última atualização:

`2026-08-29`
