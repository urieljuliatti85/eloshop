# ADR 008 — Solicitações pós-venda (desistência, problema e reembolso)

## Status

Proposed — desenho registrado em 2026-10-31, **sem implementação**. O Uriel
decidiu reservar a tarefa e não implementar agora. As decisões de negócio
listadas abaixo já foram tomadas; uma segue pendente com o advogado.

É a primeira condição do parecer jurídico de 2026-10-29 (Marcos Alex Silva,
OAB/ES 39.173) para publicar a política de trocas e devoluções (PR #172), e o
item 6 do texto da política ("utilize a ferramenta… na área da sua compra").

## Contexto

O Decreto nº 7.962/2013 (art. 5º) exige que o comprador possa desistir **pela
mesma ferramenta usada na compra**, receba **confirmação imediata** e que o
fornecedor comunique o estorno de imediato ao meio de pagamento. Hoje:

* `Orders::Cancel` só cancela pedido sem pagamento aprovado. Com o pedido pago,
  o comprador vê "Cancelar pedido", que recusa com "use reembolso", e não tem
  como pedir nada pelo site — só pelo e-mail contato@eloshop.shop.
* `Payments::Refund` funciona, é idempotente e devolve a comissão
  proporcionalmente, mas só o admin dispara, pela tela do pedido.
* `OrderMessage` é conversa entre comprador e ateliê; o admin não participa, e
  não há protocolo.
* `SellerOrder#production_started_at` e a entrega informada pelo comprador
  existem e servem de fato para o atendimento — **nunca** para bloquear a
  desistência (parecer: o art. 49 do CDC não traz essa exceção).

## Decisão (desenho)

Uma entidade nova, `ReturnRequest` ("Solicitação" na interface), presa ao
`SellerOrder` — é por ateliê que se devolve e reembolsa.

| Campo | Para quê |
|---|---|
| `kind`: `withdrawal` (desistência), `product_issue` (vício, avaria, peça diferente), `delivery_issue` (atraso, não recebido) | Procedimentos distintos, como o parecer exige |
| `protocol` (ex.: `ELO-2026-000123`, índice único) | Protocolo do decreto |
| `status`: `received` → `in_progress` → `awaiting_return` → `resolved` / `closed`, com transições explícitas | Estado explícito, padrão do projeto |
| `description` e fotos **opcionais** (Active Storage, tipo e tamanho validados) | "A falta de fotografias não impede o exercício de direitos" |
| `respond_by` (2 dias úteis) | Prazo prometido na política; ordena a fila do admin |
| `within_withdrawal_window` (a partir da entrega) | **Informativo** para o admin; nunca recusa o pedido |

Histórico em `ReturnRequestUpdate` (autor comprador, ateliê ou admin; texto;
mudança de status). O protocolo também entra no `OrderEvent` do pedido.

**Fluxo**

1. Comprador: botão "Desistir da compra ou relatar um problema" na página do
   pedido; escolhe o tipo, descreve, anexa fotos se quiser. A tela mostra o
   protocolo na hora, e um e-mail com o protocolo sai em seguida (job, depois
   do commit). Página da solicitação com o histórico, onde ele também responde.
2. Admin: fila em `/admin/solicitacoes`, ordenada pelo prazo, com atrasadas em
   destaque. Responde, muda o status e **reembolsa** a partir da solicitação,
   reaproveitando `Payments::Refund` (integral com frete na desistência).
   Pedido ainda não enviado: "cancelar e reembolsar" num clique
   (`Orders::CancelAndRefund`: reembolso, estoque e status na ordem certa).
3. Ateliê: vê as solicitações dos próprios pedidos (escopo por
   `current_seller`) e acrescenta informação. **Não decide** (Anexo II do
   parecer).
4. Notificação e e-mail a cada mudança, para comprador, ateliê e admin. Um job
   diário avisa o admin das solicitações perto do prazo.

Banco: tabelas `return_requests` e `return_request_updates` com chaves
estrangeiras, protocolo único e índice único parcial que impede duas
solicitações abertas do mesmo tipo para o mesmo pedido.

## Decisões do negócio (2026-10-31)

* **Desistência antes do envio:** um clique do admin ("cancelar e
  reembolsar"), não automático nesta primeira versão.
* **Dias úteis:** segunda a sexta, sem feriados.
* **Devolução física sem custo ao comprador:** espera a etiqueta da SuperFrete.
  Até lá, o status `awaiting_return` registra o código de postagem que o
  ateliê informar.

## Pendente

* **Quando reembolsar na desistência depois da entrega** — ao receber o pedido
  do comprador ou quando a peça for postada de volta. O parecer fala em
  providências "imediatas". **Pergunta para o advogado.** Até a resposta: o
  admin decide caso a caso, com o botão de reembolso disponível desde o
  primeiro minuto.

## Condições externas (não bloqueiam construir, bloqueiam publicar a política)

* **Saldo na conta Mercado Pago da EloShop (143360137).** No split 1:1, todo
  reembolso subtrai proporcionalmente da conta do vendedor e da do
  marketplace (documentação do Mercado Pago, "Integrar o checkout em Split de
  Pagamentos 1:1"; confirmado no chamado WCS-53635). Sem saldo disponível em
  qualquer das duas, o Mercado Pago recusa com `Collector hasn't enough
  available money` (`Gateways::MercadoPago::InsufficientFunds`) — foi o que
  travou o pedido 54. Exige reserva na conta da plataforma (valor: decisão do
  Uriel) e validar refazendo os reembolsos de teste dos pedidos 54 e 55.
* **Termos do Artesão:** obrigação de manter saldo para reembolsos (ou
  compensação nas vendas seguintes) e frete da devolução por conta do ateliê.
  Nova versão, novo aceite.

## Riscos

* Estorno travado por falta de saldo: a tela do admin precisa dizer de qual
  lado faltou, reaproveitando o tratamento de `InsufficientFunds`.
* Reembolso duplicado: coberto pela idempotência de `Payments::Refund`; a
  solicitação gera uma chave estável por reembolso.
* Prazo de 2 dias úteis estourado com uma pessoa só atendendo: risco
  operacional, mitigado pela fila e pelo aviso diário.
* Fotos são dado pessoal: validação como os demais uploads, e a Política de
  Privacidade precisa mencioná-las.
* Isolamento entre ateliês: teste de troca de ID na URL, como no resto do
  painel.

## Testes previstos

* Minitest: protocolo único e prazo em dias úteis; transições inválidas
  recusadas; duplicata barrada no banco; "cancelar e reembolsar" devolve
  valor integral com frete e o estoque, sem reembolsar duas vezes; desistência
  nunca recusada por produção ou prazo.
* RSpec: comprador só nos próprios pedidos; protocolo na resposta; ateliê sem
  acesso a pedidos de outro; só admin reembolsa; `rate_limit`; e-mails
  enfileirados.
* Sistema: comprador abre a solicitação pelo pedido e vê o protocolo.

## Critérios de aceite

* Em pedido pago, o comprador abre solicitação de qualquer dos três tipos, sem
  bloqueio por prazo ou produção, e recebe o protocolo na tela e por e-mail.
* O admin vê a fila com o prazo, responde e reembolsa a partir da solicitação;
  pedido não enviado cancela e reembolsa num clique, com frete e estoque.
* O ateliê vê e responde as solicitações dos próprios pedidos, e nenhuma de
  outro.

## Ao retomar

Branch prevista `feat/solicitacoes-pos-venda`, um PR, sem publicar a política
junto (ela segue no #172 até as condições do parecer serem cumpridas).
