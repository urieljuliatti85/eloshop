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

`TODO — DECISION REQUIRED`: se e quando a complexidade de autorização justificar, decidir se será usada uma gem dedicada (ex. Pundit) ou uma implementação simples baseada em métodos explícitos nos controllers/models. Não decidir isso preventivamente sem necessidade real (ver `CLAUDE.md`, seção "Autorização").

## Multi-tenancy / marketplace

O sistema é, por padrão, uma loja única (não um marketplace multi-vendedor). Caso a necessidade de múltiplos artesãos/vendedores surja, não modelar automaticamente como marketplace — isso implica comissões, repasses, contas e pedidos divididos, que são decisões de negócio significativas.

`TODO — DECISION REQUIRED`: se a loja deverá suportar múltiplos artesãos como entidades comerciais independentes (marketplace) ou apenas como um atributo informativo do produto.
