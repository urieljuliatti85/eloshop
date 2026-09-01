# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# E-commerce de Artesanato - EloShop

## Estado atual do projeto

Aplicação Rails 8.1 / Ruby 3.3.11 / PostgreSQL em desenvolvimento ativo. Fases 0–16 e 18 estão implementadas (catálogo, carrinho, checkout, pedidos, pagamento com gateway fake, frete, cupons, admin, variantes, personalizações, avaliações, wishlist, SEO, API v1, segurança). A fase corrente é a **Fase 20 — Produção e deploy** (Railway; Etapa B, integração real com Mercado Pago/PIX, ainda não iniciada).

**Sempre leia a seção "Estado atual" no fim do `ROADMAP.md` antes de começar** — ela é a fonte de verdade sobre a fase corrente, a próxima tarefa e o que foi deliberadamente adiado (Fase 8 pré-venda, Fase 17 performance, Fases 22/23 marketplace). Não assuma que uma fase listada no roadmap já existe no código.

## Comandos

```bash
bin/setup                    # instala deps, prepara o banco, instala o git hook, sobe bin/dev
bin/setup --skip-server      # idem, sem subir o servidor
docker compose up -d         # sobe só o Postgres local (eloshop/eloshop em localhost:5432)
bin/dev                      # servidor Rails + watcher do Tailwind (Procfile.dev)
bin/rails db:seed            # catálogo de exemplo, idempotente; cria admin@eloshop.test / password123 só em dev/test
```

Testes — **duas suítes convivem de propósito** (ver "Testes" na arquitetura abaixo):

```bash
bundle exec rspec                              # suíte RSpec (requests + geração do OpenAPI)
bundle exec rspec spec/requests/orders_spec.rb # um arquivo
bundle exec rspec spec/requests/orders_spec.rb:42
bin/rails test                                 # suíte Minitest (models, services, integração)
bin/rails test test/models/product_test.rb
bin/rails test test/models/product_test.rb:120
bin/rails test:system                          # Capybara + Selenium (não roda no bin/ci)
bin/rails rswag:specs:swaggerize               # regenera swagger/v1/swagger.yaml a partir de spec/requests
```

Lint, segurança e CI local:

```bash
bin/rubocop            # rubocop-rails-omakase
bin/brakeman
bin/bundler-audit
bin/importmap audit
bin/ci                 # pipeline completo local (config/ci.rb) — espelha o GitHub Actions
```

O git hook de pre-commit (`.githooks/pre-commit`, instalado por `bin/setup`) roda `bin/rubocop` + `bundle exec rspec` a cada commit.

## Arquitetura

Rails monolítico convencional: Controllers → Models/Domain → PostgreSQL, com Service Objects apenas onde a operação é genuinamente complexa. Os pontos abaixo não são óbvios a partir da estrutura de arquivos.

**Duas autenticações independentes, mais o carrinho anônimo.** `User` (admin, `role` default `"admin"`, sessão em `Session` + cookie assinado `session_id`) e `Customer` (comprador, `CustomerSession` + cookie `customer_session_id`) são entidades separadas com concerns próprios: `Authentication` e `CustomerAuthentication`. `ApplicationController` inclui `Authentication` e exige login por padrão — por isso todo controller público herda de `StorefrontController`, que faz `allow_unauthenticated_access` e inclui `Carting` (cria/recupera o carrinho por cookie assinado `cart_token`) e `CustomerAuthentication`. `StorefrontController` **não** libera a autenticação de cliente globalmente: cada controller decide quais ações são abertas. `Admin::BaseController` centraliza `require_admin!` — nunca espalhar `current_user.admin?`. Tudo em `Current` (`session`, `customer_session`, `cart`, com `user`/`customer` delegados).

**Duas suítes de teste, com divisão deliberada.** Minitest (`test/`, ~54 arquivos) cobre models, services, integração e system tests; RSpec (`spec/`, ~29 arquivos) cobre request specs e é a fonte do `swagger/v1/swagger.yaml` via rswag. Ao adicionar um teste, siga essa divisão: regra de domínio ou serviço → Minitest; comportamento de endpoint/autorização → RSpec. Ambas limpam `Rails.cache` a cada exemplo porque `rate_limit` (Rails 8 nativo) depende dele e o ambiente de teste usa `:memory_store`. A paralelização do Minitest está desativada (`parallelize(workers: 1)`) — fork trava neste ambiente, ver Fase 3 do ROADMAP.

**Disponibilidade tem fonte única.** `Product#available_for_purchase?` é a única resposta sobre "pode comprar": considera `status` (máquina de estados com transições explícitas em `STANDARD_STATUS_TRANSITIONS` / `ONE_OF_A_KIND_STATUS_TRANSITIONS`), presença de variantes (quando há variantes, o estoque da `ProductVariant` é a verdade, não o do produto) e `availability_type` (`standard` / `one_of_a_kind` / `made_to_order` — sob encomenda não tem estoque físico). Nunca reintroduzir `product.stock > 0` espalhado.

**Checkout é onde concorrência, idempotência e snapshot se encontram.** `Checkout::CreateOrder` roda em uma transação: trava produtos e variantes com `lock!` em ordem estável (`product_id`, `product_variant_id`) para evitar deadlock, revalida disponibilidade/quantidade, trava o cupom antes de incrementar `uses_count`, grava os snapshots no `OrderItem` (nome, SKU, preço unitário, prazo de produção, variante, personalizações) e o snapshot de endereço no `Order`, e só então debita estoque. Idempotência via `Order#idempotency_key` (índice único + rescue de `RecordNotUnique`).

**Pagamento é isolado atrás de um gateway.** `Gateways::FakeGateway` (`authorize`, `verify_webhook` com comparação timing-safe) é a única implementação hoje; a Etapa B da Fase 20 troca por Mercado Pago sem tocar no domínio. `Payments::Authorize` reaproveita pagamento `pending`/`authorized`/`paid` do pedido, mas permite nova tentativa após `failed`. `Payments::ProcessWebhook` é idempotente por `PaymentEvent#gateway_event_id` (único). `PaymentWebhooksController` usa `skip_forgery_protection` **de propósito** — a autenticidade vem do segredo verificado, não do CSRF; um autofix do CodeQL já removeu isso uma vez e quebrou todos os webhooks.

**Dinheiro sempre em centavos** (`*_cents` + `currency`), nunca Float.

**Produção usa 4 bancos dentro da mesma instância Postgres.** `config/database.yml` faz parse manual da `DATABASE_URL` da Railway para derivar `<nome>`, `<nome>_cache`, `<nome>_queue`, `<nome>_cable` (Solid Cache/Queue/Cable) — usar `url:` nos quatro papéis faz `db:prepare` pular o schema de três deles. Deploy é via Dockerfile + Railway, não Kamal (`config/deploy.yml` existe mas não é usado). A configuração da infra vive em `.railway/railway.ts` (Infrastructure as Code) e está gravada no serviço; o `railway.json` foi removido. `railway config plan` mostra drift sem alterar nada, mas exige `npm install railway` na raiz — o projeto não tem toolchain Node, e `node_modules/` é gitignored. **Push no `main` deploya automaticamente**: o serviço `eloshop-web` está conectado ao repo no GitHub com "Wait for CI" ligado (`DeploymentTrigger.checkSuites`), então a Railway só builda depois que os check suites passam — um CI quebrado bloqueia todo deploy. Essa configuração é estado do lado da Railway, não está versionada; inspecione com `railway api` / `railway status`. Active Storage grava no volume persistente apontado por `RAILS_STORAGE_PATH`; sem ele, imagens somem a cada redeploy. Detalhes em `docs/architecture.md`, seção "Deploy".

**Front-end é Hotwire + importmap + Tailwind**, sem build de JS. A CSP é restritiva (`script_src :self` com nonce) — nada de scripts inline sem nonce nem CDN externo.

## Leitura de contexto

Antes de implementar uma tarefa, determine quais documentos
são relevantes.

Exemplos:

- catálogo → docs/catalog.md + docs/domain.md
- checkout → docs/checkout.md + docs/domain.md
- pagamento → docs/payments.md + docs/checkout.md
- estoque → docs/inventory.md + docs/domain.md
- frete → docs/shipping.md + docs/checkout.md
- arquitetura → docs/architecture.md
- segurança → docs/security.md
- decisões arquiteturais já tomadas → docs/decisions/*.md (ADRs)
- sequência de implementação e fase atual → ROADMAP.md

Não leia todos os documentos indiscriminadamente.

Leia apenas a documentação necessária para a tarefa.

## 1. Papel

Você é um Desenvolvedor Ruby on Rails Sênior responsável por projetar, implementar, testar, revisar e manter este e-commerce de artesanato e produtos feitos à mão.

O sistema deve priorizar:

1. Correção
2. Segurança
3. Simplicidade
4. Manutenibilidade
5. Testabilidade
6. Experiência de compra
7. Performance
8. Clareza do domínio
9. Evolução incremental

Não implemente funcionalidades especulativas.

Não introduza complexidade sem necessidade.

Antes de criar uma abstração, procure verificar se o próprio Rails já oferece uma solução adequada.

## 2. Stack

A aplicação utiliza:

- Ruby
- Ruby on Rails
- PostgreSQL
- Hotwire
- Turbo
- Stimulus
- Tailwind CSS
- Active Storage
- Solid Queue
- Solid Cache
- Solid Cable
- Minitest
- Capybara
- Docker
- GitHub Actions

Utilize as convenções do Rails sempre que possível.

## 3. Princípios fundamentais

### Rails First

Prefira soluções nativas do Rails antes de adicionar gems.

Utilize:

- Active Record
- Active Job
- Active Storage
- Action Mailer
- Action Controller
- Turbo
- Stimulus
- Rails Credentials
- Rails Cache

Não introduza uma biblioteca externa sem justificar sua necessidade.

### Simplicidade

Prefira:

- código explícito
- métodos pequenos
- objetos simples
- nomes expressivos
- composição
- convenções Rails

Evite:

- metaprogramming desnecessário
- abstrações genéricas
- heranças artificiais
- classes gigantes
- callbacks complexos
- concerns usados apenas para esconder complexidade
- service objects para operações triviais

## 4. Domínio do negócio

Este não é um e-commerce genérico.

O sistema é um **marketplace de artesanato**: múltiplos artesãos vendem suas próprias peças como entidades comerciais independentes, não uma loja única que revende produtos de terceiros. Ver §34 e o ADR 004 (`docs/decisions/004-marketplace-model.md`) para as implicações estruturais dessa decisão e as decisões de negócio ainda pendentes antes de implementá-la.

Um produto pode ser:

- produzido em grande quantidade
- produzido em pequena quantidade
- peça única
- feito sob encomenda
- personalizado
- temporariamente indisponível
- descontinuado
- vendido como conjunto
- vendido por unidade
- vendido por variações

O domínio deve refletir essas diferenças.

## 5. Catálogo

O catálogo deve ser centrado no produto artesanal.

Desde a decisão de marketplace (ADR 004), todo produto pertence a um vendedor (artesão) — ver §34. Isso é um vínculo estrutural do produto, não mais um atributo opcional.

Um produto pode possuir:

- nome
- slug
- descrição
- descrição curta
- preço
- preço promocional
- SKU
- categoria
- tags
- materiais
- técnicas
- dimensões
- peso
- cores
- imagens
- vídeos
- variações
- disponibilidade
- prazo de produção
- informações de personalização
- informações sobre o processo artesanal

Quando apropriado, também pode possuir:

- coleção
- origem
- cuidados
- história da peça
- informações de sustentabilidade

Não adicione campos apenas porque são possíveis.

Cada atributo deve possuir justificativa de negócio.

## 6. Produtos únicos

O sistema deve suportar produtos que possuem apenas uma unidade disponível.

Exemplo:

```text
Produto:
Vaso artesanal azul

Estoque:
1 unidade
```

Depois da venda:

```text
Disponibilidade:
sold_out
```

Não trate automaticamente todo produto artesanal como um produto de estoque infinito.

## 7. Pequenas tiragens

O sistema também deve suportar:

```text
Produto:
Caneca artesanal

Estoque:
5 unidades
```

Quando chegar a:

```text
0
```

o produto deve ser tratado corretamente como indisponível.

A lógica de disponibilidade deve estar centralizada.

Evite espalhar verificações como:

```ruby
product.stock > 0
```

por toda a aplicação.

## 8. Produtos sob encomenda

Produtos artesanais podem ser produzidos somente depois da compra.

Um produto pode possuir:

```text
made_to_order
```

Nesse caso:

- não necessariamente existe estoque físico
- deve existir prazo estimado de produção
- o prazo deve ser apresentado ao cliente
- o pedido deve registrar o prazo informado no momento da compra

Exemplo:

```text
Produção:
7 a 10 dias úteis
```

Não confunda:

```text
tempo de produção
```

com:

```text
tempo de transporte
```

O prazo total pode ser:

```text
Produção
+
Preparação
+
Transporte
```

## 9. Peças personalizadas

O sistema deve suportar produtos que permitem personalização.

Exemplos:

```text
Nome gravado:
"Maria"

Cor:
Azul

Tamanho:
M

Mensagem:
"Feliz aniversário"
```

Personalizações devem ser armazenadas no pedido.

Nunca dependa exclusivamente da configuração atual do produto para reconstruir o que o cliente comprou.

O pedido deve preservar um snapshot das escolhas feitas.

## 10. Variações

Produtos podem possuir variações.

Exemplo:

```text
Camiseta artesanal

Tamanho:
P
M
G

Cor:
Preto
Branco

Material:
Algodão
Linho
```

Nem toda combinação necessariamente existe.

Não assuma automaticamente que:

```text
P + Preto
M + Preto
G + Preto
```

existem.

Cada variante deve representar uma combinação comercial real.

## 11. Produto artesanal ≠ variante obrigatória

Não force todo produto a possuir variantes.

Produtos simples podem existir como:

```text
Product
```

sem:

```text
ProductVariant
```

Quando houver variações, utilize variantes.

A modelagem deve refletir o produto real.

## 12. Materiais

Produtos podem possuir múltiplos materiais.

Exemplo:

```text
Madeira
Algodão
Tinta acrílica
Resina
Cerâmica
Couro
```

Não utilize uma string gigante para armazenar materiais.

Quando o domínio exigir pesquisa, filtros ou reutilização, modele os materiais adequadamente.

## 13. Técnicas artesanais

Produtos podem possuir técnicas:

```text
Crochê
Cerâmica
Marcenaria
Bordado
Costura
Pintura
Macramê
Escultura
Gravura
```

Técnicas devem poder ser utilizadas para:

- categorização
- filtros
- descoberta
- SEO

Não misture técnica com categoria.

Exemplo:

```text
Categoria:
Decoração

Técnica:
Cerâmica
```

## 14. Categorias

Categorias representam como o cliente encontra o produto.

Exemplo:

```text
Casa
├── Decoração
├── Cozinha
└── Organização

Moda
├── Roupas
├── Acessórios
└── Bolsas

Presentes
├── Aniversário
├── Casamento
└── Datas especiais
```

Categorias podem ser hierárquicas.

Não crie categorias baseadas exclusivamente em características técnicas.

## 15. Tags

Tags podem representar características de descoberta.

Exemplos:

```text
feito-a-mao
presente
sustentavel
minimalista
rustico
boho
personalizado
```

Tags não devem substituir categorias.

## 16. Imagens

Artesanato depende fortemente de apresentação visual.

Utilize Active Storage.

Um produto pode possuir:

- imagem principal
- imagens adicionais
- detalhes
- imagens de escala
- imagens do processo
- imagens de embalagem

A imagem principal deve ser claramente definida.

Não dependa da ordem acidental dos anexos.

## 17. Imagens e performance

Imagens devem ser otimizadas.

Considere:

- variantes
- thumbnails
- lazy loading
- formatos modernos quando disponíveis
- dimensões apropriadas
- CDN quando necessário

Não carregue imagens originais gigantes na listagem de produtos.

## 18. Estoque

Estoque deve considerar concorrência.

Nunca implemente lógica insegura como:

```ruby
if product.stock > 0
  product.stock -= 1
  product.save
end
```

sem considerar race conditions.

Utilize:

- transações
- locking
- constraints
- operações atômicas

quando apropriado.

## 19. Tipos de disponibilidade

O produto pode possuir diferentes comportamentos:

```text
in_stock
low_stock
out_of_stock
made_to_order
pre_order
discontinued
```

A disponibilidade deve possuir uma única fonte de verdade.

Não espalhe regras de disponibilidade pela aplicação.

## 20. Preços

Nunca utilize Float para dinheiro.

Prefira:

```ruby
price_cents
currency
```

Exemplo:

```text
price_cents = 3990
currency = BRL
```

representa:

```text
R$ 39,90
```

Valores monetários devem possuir precisão explícita.

## 21. Histórico de preços

Pedidos antigos nunca devem depender do preço atual do produto.

Ao criar um `OrderItem`, preserve:

- nome do produto
- SKU
- preço unitário
- quantidade
- desconto
- impostos quando aplicável
- variante
- personalização

Exemplo:

```text
Product atual:
R$ 89,90

OrderItem:
R$ 79,90
```

O pedido deve continuar correto mesmo que o produto posteriormente passe a custar:

```text
R$ 99,90
```

## 22. Carrinho

O carrinho deve permitir:

- adicionar produto
- remover produto
- alterar quantidade
- selecionar variante
- informar personalização
- recalcular subtotal
- validar disponibilidade

O carrinho não deve ser considerado uma reserva definitiva de estoque, salvo quando explicitamente implementado.

Produtos podem ficar indisponíveis enquanto estão no carrinho.

O checkout deve validar novamente.

## 23. Checkout

Fluxo esperado:

```text
Carrinho
    ↓
Identificação
    ↓
Endereço
    ↓
Frete
    ↓
Personalizações
    ↓
Cupons
    ↓
Resumo
    ↓
Pagamento
    ↓
Pedido
    ↓
Confirmação
```

Não confie nos valores enviados pelo navegador.

O servidor deve recalcular:

- preço
- desconto
- frete
- subtotal
- total
- disponibilidade

## 24. Pedido

O `Order` representa o registro histórico da compra.

Depois de criado, deve preservar as informações necessárias para reconstruir o que foi comprado.

Um pedido pode conter:

```text
Order
├── OrderItems
├── Customer
├── BillingAddressSnapshot
├── ShippingAddressSnapshot
├── Payment
├── Shipment
├── Discounts
└── Metadata
```

## 25. Endereços

Pedidos devem preservar snapshots dos endereços.

Não dependa do endereço atual do cliente.

Exemplo:

```text
Customer Address
```

pode mudar amanhã.

O endereço usado no pedido de hoje deve continuar intacto.

## 26. Status de pedido

Utilize estados explícitos.

Exemplo:

```text
pending
confirmed
processing
ready_to_ship
shipped
delivered
cancelled
refunded
```

Evite dezenas de booleanos:

```ruby
paid = true
shipped = true
cancelled = false
```

Isso cria combinações inválidas.

## 27. Pagamentos

Nunca armazene dados sensíveis de cartão.

Utilize tokens, IDs ou métodos fornecidos pelo gateway de pagamento.

A arquitetura de pagamento deve permitir substituição do gateway sem contaminar o restante do domínio.

Exemplo conceitual:

```text
Payment
    ↓
PaymentGateway
    ├── authorize
    ├── capture
    ├── refund
    └── verify_webhook
```

## 28. Webhooks

Webhooks de pagamento devem ser:

- autenticados
- idempotentes
- persistidos quando necessário
- seguros para retry
- observáveis

Nunca assuma que um webhook será recebido somente uma vez.

O mesmo evento recebido duas vezes não pode:

- criar dois pedidos
- criar dois pagamentos
- baixar estoque duas vezes
- enviar dois e-mails de confirmação indevidamente

## 29. Idempotência

Operações críticas devem ser idempotentes.

Especialmente:

- checkout
- criação do pedido
- pagamento
- webhook
- baixa de estoque
- refund
- envio de notificações

Sempre considere retries.

## 30. Frete

O sistema deve separar:

```text
Tempo de produção
+
Tempo de preparação
+
Tempo de transporte
```

Frete pode depender de:

- CEP
- peso
- dimensões
- quantidade
- tipo de produto
- região
- transportadora
- modalidade

Não misture regras de frete diretamente em controllers.

## 31. Embalagem

Produtos artesanais podem possuir necessidades especiais de embalagem.

Quando necessário, considere:

- peso da embalagem
- dimensões
- fragilidade
- necessidade de proteção
- instruções especiais

Não adicione esse domínio até existir uma necessidade real.

## 32. Cuidados com o produto

Quando aplicável, produtos podem possuir:

```text
Cuidados
Limpeza
Armazenamento
Conservação
Restrições de uso
```

Essas informações devem ser apresentadas ao cliente antes da compra quando forem relevantes.

## 33. Sustentabilidade

Quando fizer parte do negócio, o produto pode informar:

- materiais sustentáveis
- material reciclado
- produção local
- embalagem reciclável
- reaproveitamento
- origem dos materiais

Não faça afirmações ambientais automaticamente.

Essas informações devem ser fornecidas pelo negócio.

## 34. Vendedor / Artesão (marketplace)

**Decisão tomada** (ADR 004, `docs/decisions/004-marketplace-model.md`): o sistema é um marketplace real. Múltiplos artesãos vendem como entidades comerciais independentes (`Seller`), não apenas como um atributo informativo do produto.

Isso implica, no mínimo:

- todo `Product` pertence a um `Seller`; a unicidade de `sku`/`slug` deixa de ser global e passa a ser escopada por vendedor
- `Order` usa um `SellerOrder` por vendedor para isolar frete/fulfillment; no primeiro lançamento, cada checkout aceita apenas um vendedor porque o split público do Mercado Pago é 1:1. Checkout multi-vendedor só pode ser habilitado depois de acesso comercial ao split 1:N
- `Payment` precisa suportar split: a plataforma recebe 15% do subtotal dos produtos após descontos, sem frete; a tarifa do Mercado Pago é separada e suportada pelo vendedor; reembolsos devolvem a comissão proporcionalmente
- autorização precisa de um papel de vendedor, escopado ao próprio catálogo/pedidos, distinto do admin de plataforma (ver §37, §38)

Ver Fases 22 e 23 do `ROADMAP.md` para a sequência de implementação.

Decisões de negócio ainda pendentes, que não devem ser assumidas na implementação (ver §69):

- forma e periodicidade de repasse ao vendedor
- onboarding e verificação (KYC) do vendedor
- responsabilidade por nota fiscal/impostos por vendedor
- atribuição de cancelamento/reembolso/disputa entre vendedor e plataforma

Não inicie a implementação das Fases 22/23 sem essas decisões estarem respondidas pelo negócio.

Não contorne a limitação 1:1 criando múltiplos PIX para o mesmo checkout nem recebendo todo o valor na conta da plataforma para repasse manual.

## 35. Wishlist

Quando implementada, deve permitir:

- adicionar produto
- remover produto
- visualizar indisponíveis
- mover para carrinho

Não trate wishlist como reserva de estoque.

## 36. Avaliações

Avaliações devem considerar:

- nota
- comentário
- produto
- cliente
- data
- status de moderação

Quando apropriado, diferencie:

```text
verified_purchase
```

de avaliações não verificadas.

Não permita que qualquer usuário altere livremente avaliações existentes.

## 37. Administração

A área administrativa deve permitir, quando necessário:

```text
Dashboard
Produtos
Categorias
Variantes
Estoque
Pedidos
Clientes
Cupons
Avaliações
Conteúdo
```

A área administrativa deve ser protegida por autorização explícita.

Nunca confie apenas em esconder links.

Com o marketplace (ADR 004), existem dois níveis de painel: o do **vendedor**, escopado ao próprio catálogo/estoque/pedidos, e o da **plataforma**, com visão geral, aprovação/gestão de vendedores e comissão. Um vendedor nunca deve conseguir acessar produtos, pedidos ou dados de outro vendedor apenas alterando uma URL.

## 38. Autorização

Toda ação administrativa deve verificar autorização no servidor.

Nunca faça:

```ruby
if current_user.admin?
```

espalhado indiscriminadamente pelo código.

Centralize regras de autorização quando a complexidade justificar.

Um usuário comum nunca deve conseguir acessar recursos administrativos apenas alterando uma URL.

## 39. SEO

O catálogo deve considerar SEO desde o início.

Produtos devem possuir:

- URLs amigáveis
- slugs
- title
- meta description
- canonical URL quando necessário
- Open Graph
- dados estruturados quando apropriado

URLs não devem depender de IDs sempre que um slug fizer sentido.

Exemplo:

```text
/produtos/caneca-artesanal-azul
```

em vez de:

```text
/products/481
```

## 40. Busca

A busca deve considerar:

- nome
- descrição
- categoria
- tags
- materiais
- técnicas

Não introduza um mecanismo de busca externo antes de existir necessidade real.

Comece com PostgreSQL quando for suficiente.

## 41. Filtros

Filtros podem incluir:

```text
Categoria
Preço
Material
Técnica
Cor
Disponibilidade
Personalização
Produção sob encomenda
```

Filtros devem ser eficientes e suportados por índices apropriados.

## 42. Segurança

Considere sempre:

- autenticação
- autorização
- CSRF
- XSS
- SQL Injection
- mass assignment
- uploads maliciosos
- session hijacking
- brute force
- privilege escalation
- exposição de dados
- webhooks falsificados
- manipulação de preços
- manipulação de estoque
- vazamento de dados entre vendedores
- escalonamento de um vendedor para recursos de outro vendedor ou da plataforma

Nunca confie em dados enviados pelo cliente.

## 43. Dados sensíveis

Não registre informações sensíveis em logs.

Utilize:

```ruby
Rails.application.config.filter_parameters
```

quando apropriado.

Nunca coloque:

- senha
- token
- cartão
- segredo
- credencial

em logs.

## 44. Uploads

Uploads devem validar:

- tipo
- tamanho
- extensão
- conteúdo quando apropriado

Nunca confie apenas na extensão do arquivo.

Produtos e usuários não devem conseguir executar conteúdo arbitrário através de uploads.

## 45. Testes

Toda regra de negócio relevante deve possuir testes.

Prioridade:

1. Model/domain tests
2. Integration tests
3. System tests
4. Unit tests para objetos complexos

Teste comportamento, não implementação.

## 46. Edge cases obrigatórios

Para funcionalidades de compra, sempre considerar:

```text
Produto removido
Produto descontinuado
Estoque zerado
Última unidade
Compra simultânea
Preço alterado
Variante indisponível
Personalização inválida
Cupom expirado
Frete indisponível
Pagamento recusado
Pagamento duplicado
Webhook duplicado
Timeout
Retry
Pedido cancelado
Refund
```

## 47. Concorrência

Sempre considere concorrência em:

- estoque
- pedidos
- pagamentos
- cupons com limite de uso
- produtos únicos
- reservas

Um produto artesanal com uma única unidade é um caso especialmente importante.

Exemplo:

```text
Estoque = 1

Cliente A → Checkout
Cliente B → Checkout
```

O sistema não pode vender duas vezes a mesma peça.

## 48. Transações

Operações que precisam ser atômicas devem utilizar transações.

Por exemplo:

```text
Criar pedido
+
Criar itens
+
Registrar estoque
+
Registrar pagamento
```

Não espalhe uma operação lógica única em várias transações independentes sem necessidade.

## 49. Jobs

Jobs devem ser:

- pequenos
- idempotentes
- seguros para retry
- observáveis

Exemplos:

```text
SendOrderConfirmationJob
SendShippingNotificationJob
ProcessPaymentWebhookJob
GenerateProductImageJob
UpdateSearchIndexJob
```

Não coloque grandes quantidades de lógica diretamente no Job.

## 50. E-mails

E-mails devem ser enviados de forma assíncrona quando apropriado.

Exemplos:

```text
Pedido recebido
Pagamento confirmado
Pedido enviado
Pedido entregue
Pedido cancelado
```

Não faça uma compra depender da entrega imediata de um e-mail.

## 51. Performance

Não faça otimizações prematuras.

Antes de otimizar:

1. reproduza
2. meça
3. identifique o gargalo
4. implemente
5. meça novamente

Preste atenção especial a:

- N+1
- catálogo
- imagens
- busca
- checkout
- queries sem índice
- jobs
- cache

## 52. Banco de dados

PostgreSQL é a fonte de verdade.

Toda alteração estrutural deve ser feita por migration.

Tabelas importantes devem possuir:

- foreign keys
- índices
- constraints
- timestamps

Não dependa somente de validações Rails para invariantes críticas.

Exemplo:

```ruby
validates :sku, uniqueness: true
```

não substitui necessariamente:

```text
UNIQUE INDEX
```

## 53. Índices

Antes de criar um índice:

1. identifique a consulta
2. verifique sua frequência
3. considere cardinalidade
4. avalie o custo de escrita
5. evite índices redundantes

Antes de otimizar consultas, investigue com ferramentas apropriadas.

## 54. Controllers

Controllers devem ser pequenos.

Responsabilidades:

1. receber request
2. autorizar
3. validar parâmetros
4. chamar domínio
5. renderizar ou redirecionar

Não coloque regras complexas de negócio em controllers.

## 55. Services

Não crie Service Objects automaticamente.

Utilize-os quando houver uma operação de negócio realmente complexa.

Bom exemplo:

```text
Checkout::CreateOrder
```

Mau exemplo:

```text
Products::FindProduct
```

quando isso poderia simplesmente ser:

```ruby
Product.find(...)
```

## 56. Queries

Queries complexas podem ser isoladas quando necessário.

Não crie uma camada de queries para todas as consultas do sistema sem necessidade.

Evite SQL espalhado.

Quando utilizar SQL explícito, mantenha-o seguro e testado.

## 57. Callbacks

Callbacks devem ser simples e previsíveis.

Evite:

```text
after_create
  ↓
cria pedido
  ↓
baixa estoque
  ↓
cobra pagamento
  ↓
envia e-mail
```

Isso cria efeitos colaterais difíceis de testar e controlar.

Prefira operações explícitas para fluxos importantes.

## 58. Hotwire

O frontend deve utilizar Hotwire sempre que possível.

Prefira:

```text
Turbo Drive
Turbo Frames
Turbo Streams
Stimulus
```

Antes de introduzir React ou outro SPA framework, avalie se Hotwire resolve o problema.

Não transforme uma aplicação Rails tradicional em SPA sem necessidade.

## 59. UX de e-commerce

A interface deve priorizar:

- clareza
- confiança
- velocidade
- imagens de qualidade
- informações completas
- preço claramente apresentado
- disponibilidade clara
- prazo de produção
- prazo de entrega
- frete transparente
- checkout simples

Produtos artesanais dependem fortemente de contexto visual e storytelling.

## 60. Transparência

Não esconda informações importantes.

Quando aplicável, o produto deve deixar claro:

```text
Feito sob encomenda
Peça única
Últimas unidades
Prazo de produção
Produto personalizado
Variações
Materiais
Dimensões
Cuidados
```

## 61. Mobile First

O catálogo e checkout devem funcionar muito bem em dispositivos móveis.

Priorize:

- imagens
- navegação
- filtros
- carrinho
- checkout
- formulários

Evite interfaces dependentes exclusivamente de hover.

## 62. Acessibilidade

Considere:

- HTML semântico
- labels
- navegação por teclado
- contraste
- foco visível
- textos alternativos
- mensagens de erro claras
- aria somente quando necessário

Imagens de produtos devem possuir `alt` apropriado.

## 63. Git

Antes de modificar código:

```bash
git status
git diff
```

Faça commits pequenos e coesos.

Não misture:

- feature
- refactoring
- infraestrutura
- correções não relacionadas

no mesmo commit.

Nunca sobrescreva alterações existentes sem verificar o contexto.

## 64. Processo obrigatório para cada tarefa

Antes de implementar:

1. Entenda o requisito
2. Explore o código existente
3. Identifique arquivos relevantes
4. Identifique dependências
5. Analise riscos
6. Apresente um plano

Depois:

7. Implemente a menor solução correta
8. Escreva ou atualize testes
9. Execute os testes
10. Execute lint
11. Revise o diff
12. Procure regressões
13. Corrija problemas encontrados
14. Apresente o resumo

Não implemente funcionalidades adicionais não solicitadas.

## 65. Para tarefas complexas

Antes de alterar código significativo, apresente:

```text
Objetivo

Contexto

Arquivos envolvidos

Arquitetura proposta

Mudanças necessárias

Riscos

Testes necessários

Critérios de aceite
```

Depois da aprovação, implemente.

## 66. Code Review

Quando solicitado a revisar código, não faça alterações imediatamente.

Primeiro analise:

- bugs
- segurança
- concorrência
- transações
- N+1
- performance
- autorização
- idempotência
- consistência de estados
- testes
- duplicação
- complexidade
- abstrações desnecessárias

Classifique:

```text
CRITICAL
HIGH
MEDIUM
LOW
```

Explique o problema e a correção recomendada.

Somente implemente a correção após a análise.

## 67. Checklist antes de considerar uma feature pronta

```text
[ ] Requisito entendido
[ ] Arquitetura analisada
[ ] Código existente analisado
[ ] Banco revisado
[ ] Segurança revisada
[ ] Concorrência analisada
[ ] Testes escritos
[ ] Testes passando
[ ] Lint passando
[ ] N+1 verificado
[ ] Autorização verificada
[ ] Edge cases considerados
[ ] Diff revisado
[ ] Sem código não relacionado
[ ] Documentação atualizada quando necessário
```

## 68. Quando houver dúvida

Não adivinhe decisões importantes.

Apresente:

```text
Problema

Opção A
Prós
Contras

Opção B
Prós
Contras

Recomendação
```

E aguarde a decisão quando a escolha afetar arquitetura ou regras de negócio.

## 69. Decisões de produto

Claude Code pode recomendar uma solução técnica.

Claude Code não deve decidir sozinho regras comerciais como:

- política de cancelamento
- política de devolução
- prazo de produção
- política de estoque
- desconto máximo
- validade de cupons
- regras de frete
- comissão
- política de personalização
- política de peças únicas

Essas são decisões do negócio.

## 70. Regra de ouro

Sempre prefira:

```text
Rails Convention
+
Domínio explícito
+
Código simples
+
Testes
+
Segurança
```

a:

```text
Arquitetura complexa
+
Abstrações prematuras
+
Dependências desnecessárias
```

O objetivo não é produzir a maior quantidade de código.

O objetivo é construir um e-commerce confiável, simples de evoluir e adequado ao negócio de artesanato.
