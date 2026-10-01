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

Decidido na Fase 18: `config.force_ssl = true` em produção (força HTTPS, ativa HSTS, cookies `secure`) — independente do domínio final, que é decisão da Fase 20 (deploy). `config.assume_ssl` fica para a Fase 20, já que depende de como o proxy SSL escolhido termina TLS. CSP configurada de forma estrita (`config/initializers/content_security_policy.rb`): `default-src 'self'`, importmap e Tailwind locais, com exceções explícitas e por diretiva para Mercado Pago e Google Analytics. O Google Tag Manager só entra em `script-src`/`connect-src`; os endpoints exatos de coleta entram em `img-src`/`connect-src`, sem curinga de subdomínio e sem acesso a `frame-src` ou `style-src`.

O Google Analytics é opt-in: nenhum recurso externo é carregado antes do aceite. O rastreamento existe apenas numa lista fechada de páginas públicas e recebe caminhos virtuais sem identificadores; carrinho, checkout, pedidos, conta, Admin e painel do artesão ficam fora. `GOOGLE_ANALYTICS_CREDENTIALS_JSON` é credencial apenas de servidor, preservada na Railway e ausente do HTML e dos logs. Os testes de integração travam essas fronteiras.

## Alertas de fraude de vendedor

`SellerFraudScanJob` (a cada hora, `config/recurring.yml`) roda `Fraud::SellerScan` e abre um `FraudAlert` por vendedor e regra. **Só notifica**: nada suspende, reembolsa ou avisa vendedor/cliente — isso segue decisão do admin. O aviso sai uma vez por alerta novo, por e-mail (`FRAUD_ALERT_EMAIL`, com `CONTACT_EMAIL` como fallback) e por Sentry (`warning`, sem PII, fingerprint por regra e vendedor). Os alertas abertos aparecem em `/admin/fraudes` (visão geral do marketplace: contadores, regras monitoradas e lista filtrável por situação e regra) e em `/admin/sellers/:slug`, ambos com "Marcar como resolvido".

| Regra | O que sinaliza | Fecha sozinha? |
| --- | --- | --- |
| `unverified_account` | vendedor `approved` com Mercado Pago conectado, mas conta que a aprovação não aceitaria hoje (teste ou origem desconhecida). Aprovado **sem** conexão não entra: não recebe dinheiro | não |
| `self_purchase` | pedido pago com o mesmo e-mail de um usuário do vendedor (sinal fraco, sem falso positivo) | não |
| `unshipped_paid_order` | pedido pago sem envio após 7 dias corridos (+ prazo de produção máximo, se sob encomenda) | sim, quando o envio é marcado |
| `shipped_without_tracking` | envio marcado há mais de 7 dias sem rastreio (retirada local fica de fora) | sim, quando o rastreio é informado |

O prazo de 7 dias é decisão de negócio (`Fraud::SellerScan::SHIPPING_GRACE`). **Chargeback** não vem do scan: chega pelo webhook. `charged_back` do Mercado Pago tem status próprio (antes virava `declined` e era ignorado em pagamento já pago, além de contar um `payment_failed` falso). `Payments::ProcessWebhook` chama `Fraud::RecordChargeback`, que abre o alerta `chargeback` do vendedor (ou acrescenta o pedido ao alerta aberto, sem repetir o aviso) e `Fraud::Notifier` envia o e-mail e o Sentry. **Pagamento, pedido, comissão e repasse não mudam sozinhos**: quem arca com o valor é decisão de negócio. O alerta só fecha manualmente. Depende de o webhook do app MP estar inscrito no tópico de chargebacks.

Ficam para depois, por dependerem de limiares calibrados com dados reais: pico de vendas de vendedor novo e taxa de reembolso por vendedor.

## Confirmação do formulário de contato

O formulário de contato é aberto, e o e-mail do destinatário é só o que a pessoa digitou. Por isso `ContactMailer#confirmation` ("Recebemos sua mensagem", resposta em até 2 dias úteis) tem **texto fixo**: nome, assunto e mensagem digitados nunca voltam no e-mail, para o formulário não servir de canal de spam ou golpe contra terceiros. `ContactsController` manda **no máximo uma confirmação por e-mail por hora** (chave do `Rails.cache` com o hash SHA-256 do endereço, nunca o endereço), além do `rate_limit` de 5 envios por IP em 10 minutos; a mensagem em si chega sempre a `contato@`.
