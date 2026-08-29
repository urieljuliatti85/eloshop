# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# E-commerce de Artesanato

## Estado atual do projeto

Nenhum código Rails foi gerado ainda. O repositório contém apenas documentação (`CLAUDE.md`, `ROADMAP.md`, `docs/`). Consulte `ROADMAP.md` para a fase atual e a próxima tarefa antes de assumir que qualquer model, controller ou configuração já existe — no momento a fase corrente é `FASE 0 — Fundação` (criar a aplicação Rails e configurar a base do projeto). Sempre confira a seção "Estado atual" no fim do `ROADMAP.md`, pois ela é atualizada a cada avanço de fase.

Assim que a aplicação Rails existir, adicione aqui os comandos reais de build, teste (`bin/rails test`, `bin/rails test path/to/file_test.rb`) e lint usados pelo projeto.

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

O sistema representa uma loja de artesanato, produtos autorais e itens feitos à mão.

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

- artista/artesão
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

## 34. Artesão / fabricante

O sistema pode futuramente suportar múltiplos artesãos.

Caso essa necessidade exista, não modele automaticamente como marketplace.

Primeiro determine se:

```text
Artesão
```

é apenas uma informação do produto ou se realmente é uma entidade comercial independente.

Marketplace introduz complexidade significativa:

- vendedores
- comissões
- pagamentos
- repasses
- impostos
- contas
- permissões
- pedidos divididos

Não implemente marketplace sem requisito explícito.

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


