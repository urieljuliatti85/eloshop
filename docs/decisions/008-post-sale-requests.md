# ADR 008 — Solicitações pós-venda (desistência, problema e reembolso)

## Status

Proposed — desenho registrado em 2026-10-31, **sem implementação**. Reservada
em 2026-10-31; implementação decidida em 2026-11-03, ainda sem código. As
decisões de negócio listadas abaixo já foram tomadas; uma segue pendente com o
advogado.

Revisado em 2026-11-03 (`/principal-reviewer`): o desenho foi mantido, com as
decisões A e B do Uriel e as regras de implementação da seção "Regras de
implementação". Elas são o contrato que o PR da funcionalidade precisa cumprir.

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
| `stock_restored_at` | Marca de que o estoque já voltou; garante que volte uma vez só |

Os itens devolvidos ficam em `ReturnRequestItem` (`order_item_id`, `quantity`),
desde a primeira versão (decisão B). O valor sugerido do reembolso e o estoque
devolvido saem deles; o admin pode ajustar o valor. A tela pode começar
oferecendo só o pedido inteiro, gravando todos os itens. Como o índice único
parcial permite uma única solicitação aberta por tipo e pedido, desistir de
outra peça com a desistência ainda aberta **acrescenta itens a ela** (enquanto
`received` ou `in_progress`, registrado no histórico); fechada, uma nova
solicitação pode ser aberta.

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
   (`Orders::CancelAndRefund`: só chama o reembolso com `require_unshipped`;
   estoque, status e avisos saem do `settle` — regras 1 e 2).
3. Ateliê: vê as solicitações dos próprios pedidos (escopo por
   `current_seller`) e acrescenta informação. **Não decide** (Anexo II do
   parecer). "Peça recebida de volta" registra um fato: devolve só o estoque
   dos itens da solicitação, não muda o status dela nem dispara reembolso.
4. Notificação e e-mail a cada mudança, para comprador, ateliê e admin. Um job
   diário avisa o admin das solicitações perto do prazo.

Banco: tabelas `return_requests`, `return_request_items` e
`return_request_updates` com chaves estrangeiras, `CHECK` em `kind` e `status`,
`quantity > 0`, protocolo único e índice único parcial que impede duas
solicitações abertas do mesmo tipo para o mesmo pedido. `payment_refunds`
ganha `return_request_id` (opcional, chave estrangeira): é por ele que a
solicitação mostra os próprios reembolsos e conta a tentativa `n` da chave
(ver Riscos), sob a trava do pagamento.

**A solicitação reage ao desfecho do reembolso no serviço, não na tela**
(revisão de 2026-11-03). Desde o #309 o reembolso pode ser aprovado depois,
pela reconciliação (`Payments::ReconcileRefunds` → `Payments::Refund#settle`).
Devolver o estoque, fechar a solicitação e avisar precisam partir do desfecho
aprovado dentro do `settle` — o mesmo lugar de onde já saem o e-mail ao
comprador e o aviso ao ateliê —, nunca do controller que pediu o reembolso.

**O estoque não segue o reembolso depois do envio** (revisão de 2026-11-03).
Reembolso aprovado só devolve o estoque quando a peça não foi enviada. Depois
do envio, a peça pode nem voltar (vício, avaria) ou voltar depois do
reembolso (a pendência com o advogado admite reembolsar antes da devolução);
devolver o estoque na aprovação deixaria à venda uma peça que não existe. Por
isso, depois do envio, o estoque só volta numa ação explícita de "peça
recebida de volta", do ateliê ou do admin, e nunca em `product_issue` sem
essa ação. Nos dois caminhos, o estoque volta uma única vez
(`stock_restored_at`, gravado na mesma transação) e nunca enquanto o
reembolso estiver em `processing`.

## Regras de implementação (revisão de 2026-11-03)

1. **"Cancelar e reembolsar" não abre transação nem lock em volta do
   reembolso.** `Orders::CancelAndRefund` calcula o valor e a chave e chama
   `Payments::Refund#call`, nada mais. Envolver a chamada ao Mercado Pago numa
   transação faria um timeout desfazer o `PaymentRefund` em `processing` — o
   registro que `Payments::ReconcileRefunds` usa para achar o reembolso
   remoto —, e um segundo clique reembolsaria de novo; a recusa definitiva
   também perderia o `failed`. Estoque, status e avisos saem do `settle`.
2. **A checagem "não enviado" mora dentro de `Payments::Refund#prepare_refund`**
   (ex.: `require_unshipped: true`), depois de travar Payment → SellerOrder,
   antes de reservar o valor. Envio já marcado recusa sem criar
   `PaymentRefund`. Checar fora, travando o SellerOrder antes do Payment,
   inverte a ordem de travas.
3. **Ordem de travas: Payment → SellerOrder → ReturnRequest** em todo caminho
   (`Shipment#transition_to!` segue SellerOrder → Shipment). Nenhuma ação na
   solicitação trava a `ReturnRequest` antes de chamar o reembolso.
4. **Desistência aberta trava o envio** (decisão A). `Shipment#transition_to!`
   recusa "enviado" se houver `withdrawal` aberta no SellerOrder, sob o mesmo
   lock em que já recusa durante reembolso integral em `processing`. O admin
   destrava fechando a solicitação (ex.: o comprador voltou atrás).
5. **A solicitação não espelha o estado do reembolso.** Nada de status
   "reembolsando": "em processamento / recusado / aprovado" é lido de
   `payment_refunds.where(return_request_id:)`. A recusa tem três caminhos (o
   `RequestRejected` em `call`, o `settle` com status não aprovado e a
   desistência por tempo em `ReconcileRefunds`, que não passa pelo `settle`);
   um status próprio ficaria preso. Só a aprovação gera efeito na solicitação.
6. **Protocolo vindo de uma sequence do Postgres** (`ELO-2026-000123`), como
   `DEFAULT` da coluna (`nextval`), o que mantém `protocol` `NOT NULL` num
   passo só; nunca `MAX + 1`, que disputa sob concorrência e daria erro ao
   comprador na confirmação imediata. A numeração não reinicia por ano.
   (Derivar do `id` num segundo `UPDATE` exigiria a coluna anulável.)
7. **Fotos por controller próprio**, que autoriza comprador, ateliê (por
   `current_seller`) ou admin e redireciona para uma URL de serviço de curta
   duração (`blob.url`). A rota padrão do Active Storage
   (`/rails/active_storage/blobs/redirect/:signed_id`) não expira nem checa
   quem acessa. Tipo pelo conteúdo, tamanho e quantidade validados como nas
   fotos de produto.
8. **Fora de `require_sales_open`**: desistir é direito do comprador mesmo
   com as vendas fechadas. `rate_limit` por IP e por cliente na criação,
   escopo sempre por `Current.customer`.
9. **Reembolso de pedido com solicitação aberta passa pela solicitação.** O
   gancho do `settle` só enxerga `refund.return_request`; um reembolso feito
   pela tela antiga do pedido não devolveria o estoque de uma desistência
   antes do envio. A tela do pedido mostra a solicitação aberta e leva a ela
   em vez de oferecer o reembolso solto.
10. **A confirmação legal é a da tela.** O e-mail com o protocolo sai por job
   depois do commit; falha no e-mail não impede nem desfaz a solicitação.

## Decisões do negócio (2026-10-31)

* **Desistência antes do envio:** um clique do admin ("cancelar e
  reembolsar"), não automático nesta primeira versão.
* **Dias úteis:** segunda a sexta, sem feriados.
* **Devolução física sem custo ao comprador:** espera a etiqueta da SuperFrete.
  Até lá, o status `awaiting_return` registra o código de postagem que o
  ateliê informar.

## Decisões do negócio (2026-11-03)

* **A — Desistência aberta trava o envio:** só `withdrawal`, só antes do
  envio. Evita o frete de ida e volta e preserva o "cancelar e reembolsar"
  num clique durante o prazo de 2 dias úteis do admin.
* **B — Itens da devolução guardados desde a primeira versão**
  (`ReturnRequestItem`), mesmo que a tela comece oferecendo só o pedido
  inteiro, para não migrar solicitações abertas depois.

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

* Estorno travado por falta de saldo: o Mercado Pago devolve o mesmo erro
  (`Collector hasn't enough available money`) se faltar saldo no ateliê **ou**
  na plataforma (chamado WCS-53635), então a tela não tem como dizer de qual
  lado faltou — diz "ateliê ou plataforma", como `insufficient_funds_message`
  já faz. Quando o provedor não consegue (ateliê sem saldo, pagamento com mais
  de 180 dias), o admin devolve por outro meio e **registra** o reembolso na
  tela do pedido (desde 2026-11-03, `settlement: manual`), que passa pela mesma
  contabilidade.
* Ateliê que desconecta o Mercado Pago ou é suspenso depois da venda: desde
  2026-11-03 os tokens ficam guardados só para estorno por 181 dias depois da
  última venda (`Seller#mercado_pago_refund_credentials?`), e a cobrança nova é
  recusada. A solicitação continua reembolsável pelo gateway nesse período.
* Reembolso duplicado: coberto pela idempotência de `Payments::Refund`. A
  solicitação gera **uma chave por tentativa** (ex.: `return-request-<id>-<n>`),
  não uma chave fixa: `n` só avança depois de uma tentativa `failed`, e a
  tentativa `processing` reusa a mesma chave. Uma chave fixa faria a nova
  tentativa depois de uma recusa (ex.: falta de saldo) devolver o registro
  recusado sem chamar o Mercado Pago — desde 2026-11-03 `Payments::Refund`
  recusa explicitamente reusar a chave de uma tentativa `failed`.
* Reembolso que fica `processing` (timeout, PIX em contingência) é resolvido
  por `Payments::ReconcileRefunds` (2026-11-03); a fila do admin deve mostrar
  "em processamento" em vez de oferecer nova tentativa.
* Envio durante o "cancelar e reembolsar": desde 2026-11-03 o reembolso
  integral em `processing` trava "marcar como enviado" sob o lock do
  `SellerOrder` (decisão do Uriel: travar no reembolso). `Orders::CancelAndRefund`
  confere "não enviado" dentro de `prepare_refund`, sob esse mesmo lock, antes
  de reservar o valor (regras 1 e 2).
* Prazo de 2 dias úteis estourado com uma pessoa só atendendo: risco
  operacional, mitigado pela fila e pelo aviso diário.
* Fotos são dado pessoal: servidas só com autorização (regra 7), validação
  como os demais uploads, e a Política de Privacidade precisa mencioná-las.
* Isolamento entre ateliês: teste de troca de ID na URL, como no resto do
  painel.

## Testes previstos

* Minitest: protocolo único e prazo em dias úteis (atravessando o fim de
  semana); transições inválidas recusadas; duplicata barrada no banco;
  "cancelar e reembolsar" devolve valor integral com frete e o estoque, sem
  reembolsar duas vezes; desistência nunca recusada por produção ou prazo.
* Minitest, das regras de implementação: `require_unshipped` com envio já
  marcado recusa sem criar `PaymentRefund`; timeout do gateway deixa o
  registro em `processing` e a tentativa seguinte não reembolsa de novo;
  aprovação tardia por `ReconcileRefunds` devolve o estoque e fecha a
  solicitação uma vez só; reembolso depois do envio, ou em `product_issue`,
  não devolve estoque; "peça recebida de volta" devolve só os itens da
  solicitação, uma vez; envio recusado com desistência aberta; os testes
  atuais de `Payments::Refund` passam sem alteração.
* RSpec: comprador só nos próprios pedidos; protocolo na resposta; ateliê sem
  acesso a pedidos de outro; só admin reembolsa; `rate_limit`; e-mails
  enfileirados; foto inacessível sem login e para outro comprador ou ateliê;
  solicitação criada com as vendas fechadas; a tela do pedido com solicitação
  aberta leva a ela em vez de oferecer o reembolso solto; segunda desistência
  com a primeira aberta acrescenta itens, sem criar outra solicitação.
* Sistema: comprador abre a solicitação pelo pedido e vê o protocolo.

## Critérios de aceite

* Em pedido pago, o comprador abre solicitação de qualquer dos três tipos, sem
  bloqueio por prazo ou produção, e recebe o protocolo na tela e por e-mail.
* O admin vê a fila com o prazo, responde e reembolsa a partir da solicitação;
  pedido não enviado cancela e reembolsa num clique, com frete e estoque.
* O ateliê vê e responde as solicitações dos próprios pedidos, e nenhuma de
  outro.
* Com uma desistência aberta antes do envio, o ateliê não consegue marcar o
  pedido como enviado.
* Depois do envio, reembolsar não devolve estoque; só "peça recebida de
  volta" devolve, e uma vez.
* As dez regras de implementação estão cobertas por teste.

## Ao retomar

Branch prevista `feat/solicitacoes-pos-venda`, sem publicar a política junto
(ela segue no #172 até as condições do parecer serem cumpridas). Dois PRs, para
o que mexe em dinheiro ter revisão própria:

1. **Núcleo:** migrations, `Payments::Refund` (`require_unshipped`,
   `return_request`), gancho no `settle`, `Orders::CancelAndRefund`, trava de
   envio, botão do comprador com protocolo, fila do admin e leitura pelo
   ateliê. Os testes das regras 1, 2 e 4 vêm antes do código.
2. **Complementos:** fotos, conversa com o ateliê, "peça recebida de volta",
   avisos por e-mail e o lembrete diário de prazo.

Validar no sandbox com o ateliê de teste (compra, desistência, "cancelar e
reembolsar", comissão proporcional devolvida e estoque) antes de abrir as
vendas.
