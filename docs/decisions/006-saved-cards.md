# ADR 006 — Cartões salvos do cliente

## Status

Proposed — desenho registrado em 2026-09-13, **sem implementação**. A decisão
estrutural (escopo do cartão salvo) está tomada; cinco decisões de negócio
seguem pendentes e travam a implementação inteira, não apenas uma etapa.

Há também uma condição externa: o pagamento com cartão ainda **nunca foi
aprovado de ponta a ponta** — `/v1/payments` responde HTTP 500 `internal_error`
com `cause: []` no sandbox, aguardando chamado com o Mercado Pago (Fase 24 do
`ROADMAP.md`). A API de cartões salvos (`/v1/customers`, `/v1/customers/:id/cards`)
vive no mesmo serviço. Implementar sobre um fluxo que nunca cobrou é otimizar
antes de reproduzir (§51).

## Context

O cliente (`Customer`) informa o cartão a cada compra. O Card Payment Brick
tokeniza no navegador e a EloShop recebe apenas um `card_token` de uso único,
que `Gateways::MercadoPago#authorize_credit_card` envia para `/v1/payments`.
Nada do cartão sobrevive à transação além do que o `Payment` guarda para
exibição: `card_last_four` e `card_brand`.

Salvar cartão significa guardar um **par de identificadores permanentes do
gateway** (`customer_id` + `card_id` do Mercado Pago), nunca PAN, validade ou
CVV — isso permanece fora de questão (§27, §43). A pergunta deste ADR não é se
a EloShop pode armazenar dados de cartão (não pode), e sim **em qual conta do
Mercado Pago o cofre de cartões do cliente vive**.

O que já existe e não precisa ser construído:

* `Gateways::MercadoPago` isola o gateway atrás de `authorize`/`refund`/
  `verify_webhook` (ADR 003); acrescentar tokenização recorrente não contamina
  o domínio.
* `Payment` já tem `payment_method`, `installments`, `card_brand`,
  `card_last_four` e a idempotência por `idempotency_key`.
* `Payments::Authorize` já reaproveita tentativa e trata cartão como
  aprovação síncrona, roteando o desfecho por `Payments::ProcessWebhook`.
* `Customer` é entidade separada de `User`, com sessão própria — já existe onde
  pendurar os cartões.

O que **não** existe: qualquer noção de meio de pagamento persistido do
cliente. Não há tabela, modelo, tela nem rota.

## O bloqueio estrutural

Toda cobrança usa o access token OAuth **do artesão**, não da plataforma:
`Gateways::MercadoPago#access_token_for(order)` resolve
`order.seller_order.seller` e usa o token daquele vendedor, porque o split
público do Mercado Pago é 1:1 e cada `application_fee` sai de uma cobrança feita
na conta do vendedor (ADR 004).

Um `customer_id`/`card_id` do Mercado Pago **pertence à conta que o criou**. Um
cartão salvo durante uma compra no Ateliê A é invisível para o Ateliê B: não é
uma limitação da EloShop, é como a tokenização do provedor funciona. Um cliente
que comprou de cinco artesãos teria cinco cofres independentes.

Isso elimina a leitura intuitiva de "meus cartões salvos" como uma lista única
da conta do cliente, e força uma escolha explícita.

## Decision

**Cartão salvo é escopado ao par (cliente, vendedor).** O cofre de cartões vive
na conta Mercado Pago de cada artesão, e a EloShop persiste apenas a referência.

As alternativas foram descartadas:

* **Cofre único da conta da plataforma** — exigiria que a EloShop fosse a
  cobradora de todas as vendas e repassasse ao vendedor. Proibido pelo CLAUDE.md
  §34 e pelo ADR 004: "não centralizar o valor integral na conta da plataforma
  para repasse manual". Quebraria o split, a comissão de 15% e o modelo fiscal
  (nota fiscal é do vendedor).
* **Cofre único via split 1:N** — depende do mesmo acesso comercial que já trava
  o checkout multi-vendedor (ADR 004), e mesmo com ele a tokenização
  continuaria ligada à conta cobradora.
* **Não salvar cartão** — é o estado atual e permanece a opção correta enquanto
  as pendências abaixo não forem respondidas.

O escopo por vendedor não é um consolo: em artesanato a recompra do mesmo
ateliê é o padrão, que é exatamente onde o cartão salvo paga seu custo.

**Somente crédito.** O Mercado Pago não oferece tokenização recorrente de
cartão de débito no Brasil pelos Bricks. "Salvar cartão de débito" não é
implementável hoje e não deve ser oferecido na interface.

## Decisões de negócio pendentes

Nenhuma parte da implementação começa antes destas cinco respostas (§69).

1. **Escopo aceito pelo negócio?** O cliente verá "cartões salvos neste ateliê",
   não uma carteira única da EloShop. A interface precisa dizer isso sem
   constranger a compra. Se o negócio recusar esse recorte, o ADR morre aqui —
   não há alternativa dentro do modelo de split atual.
2. **Consentimento.** Opt-in marcado por padrão ou desmarcado? Recomendação:
   **desmarcado**, por LGPD — guardar meio de pagamento é tratamento de dado que
   o titular deve escolher ativamente, não desmarcar.
3. **CVV na recompra.** Exigir de novo reduz fraude e chargeback, e elimina boa
   parte da conveniência que justifica a funcionalidade. O Mercado Pago suporta
   os dois modos. É uma troca risco × conversão, do negócio.
4. **Responsabilidade por uso indevido.** Hoje cancelamentos, reembolsos e
   disputas são da plataforma (§34, ADR 004). Cartão salvo amplia a superfície de
   uso indevido — sobretudo se a resposta de (3) for "não exigir CVV". Fica com a
   plataforma, passa ao vendedor, ou depende do modo escolhido em (3)?
5. **Ciclo de vida.** Por quanto tempo um cartão salvo sobrevive sem uso? O que
   acontece com os cartões quando o vendedor **desconecta** a conta Mercado Pago
   (que hoje volta o `Seller` para `pending` e despublica o catálogo)? As
   referências ficam órfãs no banco da EloShop e precisam de destino definido.

## Consequences

Quando as pendências forem respondidas e a Fase 24 estiver destravada:

* **Nova tabela** `customer_payment_methods` (nome provisório): `customer`,
  `seller`, `gateway`, `gateway_customer_id`, `gateway_card_id`, `card_brand`,
  `card_last_four`, `expiration_month`, `expiration_year`, `consented_at`.
  Índice único por (`customer`, `seller`, `gateway_card_id`). Nenhum dado
  sensível de cartão — os identificadores do gateway são referências, e ainda
  assim entram em `filter_parameters` (§43).
* **`Gateways::MercadoPago`** ganha criação/consulta/remoção de cartão no cofre
  do vendedor e um caminho de `authorize` que envia `payer.id` + `card_id` em
  vez de `token` de uso único. O contrato do adapter muda; `Gateways::FakeGateway`
  precisa acompanhar, senão a suíte deixa de exercitar o fluxo.
* **Checkout** passa a ter dois caminhos de cartão — Brick para cartão novo,
  seleção para cartão salvo — sem que `Payments::Authorize` perca a retomada de
  tentativa e a idempotência que já tem.
* **Área do cliente** ganha listagem e remoção de cartões, agrupada por ateliê.
  Remover na EloShop tem de remover no cofre do vendedor também, ou o cliente
  acredita ter apagado algo que continua lá.
* **Segurança** (§42): um cartão salvo é uma credencial de compra. A seleção
  precisa ser escopada por `Current.customer` no servidor — um `id` na URL nunca
  pode alcançar o cartão de outro cliente —, e o fluxo entra no escopo de
  `bin/brakeman` e do `security-review`.
* **Desconexão do vendedor** precisa de decisão executada, não só registrada
  (pendência 5).

Enquanto isso não acontecer, o comportamento permanece o atual: o cartão é
informado a cada compra e nada é persistido.
