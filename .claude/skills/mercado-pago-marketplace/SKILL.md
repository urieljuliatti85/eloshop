---
name: mercado-pago-marketplace
description: >
  Especialista em integração do Mercado Pago para marketplaces Ruby on Rails
  com múltiplos vendedores, ateliês ou lojistas. Use quando uma funcionalidade
  envolver checkout, criação de pagamentos, Mercado Pago Checkout, conexão de
  contas de vendedores via OAuth, split de pagamentos, marketplace fees,
  recebimento e repasse de valores, identificação do vendedor responsável por
  cada item, taxas da plataforma, webhooks, idempotência, atualização do status
  financeiro dos pedidos, cancelamentos, estornos, reembolsos, chargebacks,
  conciliação e auditoria financeira. Deve projetar a integração separando
  claramente Order, Payment, Seller/Vendor, Marketplace Fee e transferência,
  preservar snapshots financeiros no momento da compra e evitar lógica de
  pagamento diretamente nos controllers ou models. Priorize as APIs e práticas
  oficiais do Mercado Pago, segurança de credenciais, tratamento de falhas,
  transações, consistência financeira, testes automatizados e arquitetura
  Rails simples e sustentável.
  ---

  # Mercado Pago Marketplace — Ruby on Rails

## Objetivo

Implementar a integração do Mercado Pago para um marketplace
multi-vendedor.

## Contexto do domínio

A aplicação possui:

- Marketplace
- Ateliês/vendedores
- Produtos
- Carrinho
- Pedido
- Itens do pedido
- Pagamentos
- Taxa da plataforma
- Repasses aos vendedores

Um pedido pode conter produtos de diferentes ateliês.

## Responsabilidades

A Skill deve saber implementar:

1. OAuth Mercado Pago
2. Conexão de vendedor
3. Checkout
4. Criação de preferência
5. Pagamento
6. Split/marketplace
7. Taxa da plataforma
8. Webhooks
9. Idempotência
10. Reembolso
11. Cancelamento
12. Conciliação
13. Auditoria
14. Tratamento de falhas

## Arquitetura Rails

Preferir:

- Controllers finos
- Service Objects
- POROs
- ActiveJob
- Transactions
- Models focados no domínio
- Minitest
- Webhooks idempotentes

Evitar:

- lógica de pagamento em controllers
- callbacks complexos
- chamadas HTTP espalhadas pelo domínio
- armazenamento de access tokens sem proteção
- confiar exclusivamente no retorno do frontend
- alterar valores financeiros de pedidos antigos

## Modelagem financeira

Valores monetários devem ser armazenados em centavos:

price_cents
fee_cents
total_cents
seller_amount_cents

Nunca utilizar Float para valores financeiros.

## Pedido

Depois que o pedido for criado, preservar snapshots:

- preço
- quantidade
- moeda
- vendedor
- taxa
- valor recebido pelo vendedor

Alterações posteriores no produto não devem modificar
o histórico financeiro do pedido.

## Mercado Pago

Toda comunicação com o Mercado Pago deve estar
isolada em uma camada de integração.

Exemplo:

MercadoPago::Client
MercadoPago::OAuth
MercadoPago::Checkout
MercadoPago::Payment
MercadoPago::Webhook

## Webhooks

Webhooks devem:

- validar a requisição
- identificar o evento
- persistir o evento quando necessário
- ser idempotentes
- nunca processar o mesmo pagamento duas vezes
- atualizar o estado financeiro de forma consistente

## Segurança

Nunca:

- armazenar secrets no código
- expor access tokens
- confiar em valores enviados pelo frontend
- considerar um pagamento aprovado somente porque o
  frontend informou sucesso

## Testes

Toda integração deve possuir testes para:

- pagamento aprovado
- pagamento recusado
- pagamento pendente
- webhook duplicado
- webhook fora de ordem
- pagamento inexistente
- vendedor desconectado
- reembolso
- cancelamento
- falha na API
- timeout
- concorrência
- idempotência

## Regra principal

Dinheiro é estado crítico.

Toda alteração financeira deve ser:

- rastreável
- idempotente
- transacional quando apropriado
- auditável
- independente do frontend