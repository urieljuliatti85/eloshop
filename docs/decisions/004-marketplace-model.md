# ADR 004 — Marketplace Model

## Status

Accepted — Fase 22 iniciada e Fase 23 implementada em 2026-09-01.

## Context

`docs/architecture.md` e `docs/domain.md` já registravam um `TODO — DECISION REQUIRED` sobre se o sistema deveria suportar múltiplos artesãos como entidades comerciais independentes (marketplace) ou apenas como um atributo informativo do produto. O negócio decidiu: o projeto passa a ser um e-commerce para artesãos venderem suas próprias peças.

Todo o sistema implementado até aqui (Fases 0–13 e 15, todas concluídas) assume loja única:

* `Product` não tem dono; `sku`/`slug` têm unicidade global.
* `Order` tem um único `Customer` e um único `Shipment`; não há divisão por vendedor.
* `Payment` é um registro por pedido, para o valor total; não existe split.
* `User` (admin) só tem o papel `admin`; não existe papel de vendedor nem identidade de vendedor em `Current`.
* `Coupon` é sempre loja-inteira.

## Decision

O sistema é um marketplace real: múltiplos artesãos (`Seller`) vendem como entidades comerciais independentes, cada um dono do seu próprio catálogo e da parte do pedido que lhe cabe, com comissão da plataforma sobre as vendas.

O modelo-alvo permite itens de vendedores diferentes em uma mesma compra: um `Order` principal representa a compra do cliente e agrega um `SellerOrder` por artesão para isolar fulfillment, frete, status, cancelamento e repasse. Essa decisão define a estrutura de negócio; os detalhes de schema e transação ficam para as Fases 22/23.

No primeiro lançamento do marketplace, cada checkout aceita itens de apenas um vendedor e cria um `Order` com exatamente um `SellerOrder`. O split público do Mercado Pago é 1:1 (marketplace + um vendedor por pagamento); o modelo 1:N depende de carteira assessorada e contato comercial. O checkout multi-vendedor só será habilitado depois de esse acesso estar confirmado. Não gerar múltiplos PIX para uma única compra e não centralizar o valor integral na conta da plataforma para repasse manual.

A comissão da plataforma é 15% do subtotal dos produtos após descontos, excluindo frete. A tarifa de processamento do Mercado Pago é separada e suportada pelo vendedor conforme as regras do gateway. Em cancelamento ou reembolso, a comissão da plataforma é devolvida proporcionalmente ao valor reembolsado. Valores monetários e a comissão efetiva devem ser preservados em centavos no snapshot do `SellerOrder`/pagamento.

## Consequences

Mudanças estruturais necessárias (ver Fases 22 e 23 do `ROADMAP.md`):

* **Product**: passa a pertencer a um `Seller`. Unicidade de `sku`/`slug`, hoje global, passa a ser escopada por vendedor.
* **Order**: agrega `SellerOrder`s; começa com exatamente um por checkout e fica preparado para múltiplos quando o split 1:N estiver disponível.
* **SellerOrder**: representa a parte comercial e operacional de um vendedor dentro da compra, com totais, status, fulfillment, cancelamento e repasse próprios.
* **Shipment**: hoje é `has_one` por `Order`; passa a pertencer ao `SellerOrder`, permitindo tracking/status próprios por vendedor.
* **Payment**: hoje é um registro único pelo valor total do pedido. Precisa suportar split, registrar a comissão de 15% sem frete e a tarifa separada do gateway, além de reversão proporcional. O ADR 003 (isolamento do gateway atrás de `PaymentGateway`) ajuda aqui, mas isso ainda não existe.
* **Autorização**: `User.role` hoje só tem o valor `admin`. Precisa de um papel de vendedor, escopado ao próprio catálogo/estoque/pedidos, distinto do admin de plataforma.
* **Coupon**: hoje é sempre loja-inteira; pode precisar de escopo por vendedor (decisão de negócio, não assumida aqui).

## Decisões de negócio confirmadas

* O repasse ao vendedor será automático, por meio do split do gateway.
* O vendedor precisa passar por aprovação/KYC da plataforma antes de publicar. O cadastro começa como `pending`; a Fase 22 não armazena documentos de KYC enquanto o provedor/processo definitivo não estiver definido.
* Nota fiscal e obrigações tributárias da venda são responsabilidade do vendedor.
* Cancelamentos, reembolsos e disputas são decididos e operados pela plataforma.

## Primeira implementação da Fase 22

`Seller` é a entidade comercial; o login continua no `User` existente, agora com papel `seller` e vínculo obrigatório ao vendedor. Produtos legados são atribuídos a um vendedor aprovado `EloShop`. `Product` pertence obrigatoriamente ao vendedor, com `sku` e `slug` únicos no escopo desse vendedor. A vitrine identifica o artesão na URL (`/artesaos/:seller_slug/produtos/:slug`).

O painel do vendedor usa escopo derivado exclusivamente de `Current.user.seller`; IDs enviados pela URL nunca definem o vendedor. A publicação e a compra também consultam `Seller#approved?`, de modo que esconder links não é a barreira de autorização.

## Decisão de KYC e vínculo com o Mercado Pago

O Mercado Pago é o responsável pela coleta e validação dos documentos do vendedor. Para usar Split de Pagamentos 1:1, a documentação oficial exige uma conta de vendedor com identificação KYC nível 6 e autorização OAuth. A EloShop não coleta nem persiste RG, selfie, comprovante de endereço ou cópias de documentos.

O vendedor conecta a própria conta pelo fluxo OAuth Authorization Code. A EloShop persiste apenas o `user_id`/`collector_id`, `live_mode`, datas de conexão e expiração, e os access/refresh tokens cifrados com chave derivada do `secret_key_base`. A documentação pública do OAuth não devolve o nível KYC; portanto, conexão OAuth não aprova automaticamente o vendedor. Um admin da plataforma só pode aprovar uma conexão `live_mode` e confirma explicitamente o KYC 6 antes de chamar `Seller#approve!`. Desconectar a conta retorna o vendedor para `pending` e remove a publicação de seu catálogo.

O fluxo fica desabilitado de forma segura enquanto `MERCADO_PAGO_MARKETPLACE_APP_ID`, `MERCADO_PAGO_MARKETPLACE_CLIENT_SECRET` e `MERCADO_PAGO_MARKETPLACE_REDIRECT_URI` não estiverem configuradas. A ativação em produção depende de criar a aplicação Marketplace no Mercado Pago e validar o OAuth com conta de teste.

## Condição externa para checkout multi-vendedor

O acesso ao split 1:N do Mercado Pago deve ser confirmado comercialmente antes de habilitar mais de um `SellerOrder` pagável no mesmo checkout. Essa condição não bloqueia a Fase 22 nem o lançamento com um vendedor por checkout.
