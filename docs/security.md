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

`TODO — DECISION REQUIRED`: ver `docs/architecture.md` — se será usada uma gem dedicada de autorização (ex.: Pundit) ou uma implementação simples, e em que fase isso se torna necessário.

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

`TODO — DECISION REQUIRED`: limites exatos de tamanho de arquivo e lista de MIME types permitidos para imagens de produto não estão definidos — devem ser decididos na implementação da Fase 1.

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

`TODO — DECISION REQUIRED`: estratégia de rate limiting (ex.: para login, checkout, webhooks) ainda não está definida. Deve ser avaliada a partir da Fase 18 (Segurança — revisão aprofundada), ou antes, se um risco concreto for identificado durante o MVP.

## Headers de segurança

`TODO — DECISION REQUIRED`: configuração específica de headers de segurança (CSP, HSTS, etc.) não está definida — avaliar na Fase 18 ou antes do primeiro deploy em produção (Fase 20).
