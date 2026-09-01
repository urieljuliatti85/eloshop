# Security

Este documento consolida as decisões e requisitos de segurança que se aplicam a todas as fases do `ROADMAP.md`, desde o MVP.

## Autenticação

Usuários (administradores) e clientes (`Customer`) devem ser autenticados antes de acessar recursos protegidos. Ver `docs/architecture.md` para o mecanismo de autenticação escolhido para o MVP (gerador nativo do Rails).

## Autorização

Autorização deve sempre acontecer no servidor, a cada requisição. Nunca confiar em:

* links escondidos na interface
* parâmetros enviados pelo cliente (ex.: um campo `role` ou `admin` vindo do formulário)
* estado de sessão do frontend sem verificação correspondente no backend

Toda ação administrativa deve verificar autorização no backend. Um usuário comum nunca deve conseguir acessar recursos administrativos apenas alterando uma URL.

Evitar checagens de autorização espalhadas de forma ad-hoc (`if current_user.admin?`) por todo o código sem centralização, à medida que a complexidade de papéis/permissões crescer.

Decisão tomada na Fase 14 e estendida na Fase 22: implementação simples, sem gem dedicada. `User` tem os papéis `admin` e `seller`; `Admin::BaseController#require_admin!` protege a plataforma e `SellerPortal::BaseController#require_seller!` protege o painel do artesão.

O escopo do vendedor nunca vem de parâmetros da requisição. Produtos e pedidos começam em `Current.user.seller`; trocar um ID na URL por um recurso de outro vendedor resulta em 404. Vendedores `pending` ou `suspended` podem consultar o painel, mas o domínio bloqueia publicação e compra. A vitrine lista somente vendedores aprovados.

## Pagamentos

Nunca armazenar número de cartão, CVV ou dados sensíveis equivalentes. Ver `docs/payments.md` para o modelo completo de isolamento do gateway.

## Logs

Nunca registrar em logs:

* senhas
* tokens
* credenciais
* dados de cartão ou outros dados sensíveis de pagamento

Usar `Rails.application.config.filter_parameters` para garantir que esses dados nunca apareçam em logs, mesmo acidentalmente (ex.: parâmetros de request).

## Uploads

Todo upload de arquivo (ex.: imagem de produto via Active Storage) deve validar:

* tamanho máximo
* MIME type
* extensão
* conteúdo, quando apropriado (nunca confiar apenas na extensão declarada pelo arquivo)

Produtos e usuários não devem conseguir executar conteúdo arbitrário através de uploads.

Decidido na Fase 1 (`Product::MAIN_IMAGE_MAX_BYTES`/`MAIN_IMAGE_ALLOWED_CONTENT_TYPES`): máximo 5MB, apenas `image/png`, `image/jpeg` e `image/webp`. O conteúdo é validado de verdade, não só a extensão/header declarado pelo cliente — Active Storage usa Marcel para identificar o `content_type` a partir dos bytes reais do arquivo (`identify: true`, padrão, nunca desativado no código).

## Webhooks

Webhooks (ex.: de pagamento) devem ter sua autenticidade validada antes de qualquer processamento. Ver `docs/payments.md` para os requisitos completos de idempotência e segurança de webhooks.

## Entrada do usuário

Nunca confiar diretamente em dados enviados pelo cliente — isso inclui preço, total, disponibilidade e qualquer valor que o servidor seja capaz de recalcular (ver `docs/checkout.md`, princípio "nunca confiar no cliente").

Considerar sempre, em toda funcionalidade que recebe entrada externa:

* CSRF
* XSS
* SQL Injection
* mass assignment
* brute force (tentativas de login)
* session hijacking
* privilege escalation
* exposição de dados sensíveis
* manipulação de preço e de estoque via requisições forjadas

## Rate limiting

Decidido na Fase 18, usando o `rate_limit` nativo do Rails (sem gem como Rack::Attack — não se justifica com essa quantidade de regras). Todos os endpoints sensíveis a força bruta/abuso têm limite: login de admin e de cliente, cadastro de cliente, reset de senha, contato, aplicar cupom (adivinhação de código) e criar pedido (checkout). Webhook de pagamento é deliberadamente **não** limitado por IP — a autenticidade é garantida pelo segredo verificado (`Gateways::FakeGateway#verify_webhook`, comparação timing-safe), e um webhook real pode legitimamente vir sempre do mesmo IP do gateway com retries.

## Sessões

Sessão de admin (`Session`) e de cliente (`CustomerSession`) expiram por inatividade — `Session::INACTIVITY_TIMEOUT` (7 dias) e `CustomerSession::INACTIVITY_TIMEOUT` (30 dias, área menos sensível). Cada requisição autenticada renova a janela (`touch`). Cookies (`session_id`, `customer_session_id`, `cart_token`) são `httponly`, `same_site: :lax` e `secure` em produção.

## Headers de segurança

Decidido na Fase 18: `config.force_ssl = true` em produção (força HTTPS, ativa HSTS, cookies `secure`) — independente do domínio final, que é decisão da Fase 20 (deploy). `config.assume_ssl` fica para a Fase 20, já que depende de como o proxy SSL escolhido termina TLS. CSP configurada de forma estrita (`config/initializers/content_security_policy.rb`): só a própria origem para tudo (`default-src 'self'`), já que a aplicação não carrega nada externo — importmap vendoriza os pacotes JS localmente e o Tailwind é compilado num único CSS local, sem CDN nem Google Fonts.
