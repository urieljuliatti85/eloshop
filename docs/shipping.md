# Shipping

Este documento descreve as regras de frete e prazo de entrega.

## Composição do prazo total

O sistema deve sempre separar conceitualmente:

```text
Tempo de produção
+
Tempo de preparação
+
Tempo de transporte
```

"Tempo de produção" (relevante apenas para produtos feitos sob encomenda — ver `docs/inventory.md`) nunca deve ser confundido com "tempo de transporte". Um produto sob encomenda deve exibir ao cliente, no mínimo, o prazo de produção antes da compra, e esse prazo deve ser registrado no pedido no momento da compra.

## Escopo do MVP atual

Cada produto pode configurar no seu formulário do Painel do Artesão uma
entrega nacional com valor fixo por unidade e prazo máximo em dias úteis. O
produto também pode permitir retirada gratuita no ateliê. Quando há entrega e
retirada, o cliente escolhe a modalidade no checkout; o navegador envia apenas
o identificador da opção, e o servidor recalcula e valida preço e prazo antes
de criar o pedido.

Se nenhum produto configurar frete fixo, o checkout mantém o fallback interno
de R$ 15,00 mais R$ 5,00 por quilo, com prazo de 5 ou 8 dias conforme a faixa
de CEP. Assim, vendedores existentes continuam vendendo sem migração de dados.
Configurar apenas valor ou apenas prazo é inválido.

**Duas faixas e frete exigido para publicar (2026-10-27).** O valor fixo
passou a valer para o **mesmo estado do ateliê** (`fixed_shipping_*`), e um par
opcional (`fixed_shipping_interstate_*`) vale para **os demais estados**. O
`Shipping::Calculator` compara o estado do endereço do cliente com o
`Seller#origin_state`: mesmo estado cobra a primeira faixa, outro estado cobra a
segunda; sem a segunda faixa, o valor único vale para todo o Brasil; sem estado
de origem no ateliê, vale o pior caso de cada lado — o maior valor, porque quem
paga a etiqueta é o vendedor e o cliente vê o valor antes de pagar, e o maior
prazo, para o pedido não prometer menos do que o envio pode levar. Constraints no banco espelham
as validações (par completo, valores positivos, faixa interestadual só junto da
principal). Para **publicar**, o produto precisa de frete definido pelo vendedor
ou de frete grátis (`Product#seller_defined_shipping_for_publication`, no
contexto `:publication`, como peso e medidas): a tabela interna é um palpite da
plataforma e não bate com o custo da etiqueta. Produtos publicados antes da
regra seguem vendendo pela tabela; o painel lista quais são
(`Product.without_seller_defined_shipping`). Depois do deploy, rodar uma vez
`bin/rails shipping:notify_missing` avisa no sino do painel cada ateliê nessa
situação; rodar de novo não repete o aviso enquanto o anterior não for lido. A opção aparece no checkout como
"Ateliê · Frete definido pelo ateliê".

Em um carrinho com mais de um produto, os valores configurados são somados por
unidade e o maior prazo vira a promessa do pedido. Produto legado sem
configuração, quando misturado com produtos configurados, contribui com sua
parcela do fallback interno. A retirada só aparece se todos os produtos do
carrinho a permitirem.

## Frete real (Fase 12)

Quando implementado, o cálculo de frete pode depender de:

* CEP de destino
* peso do produto
* dimensões
* quantidade de itens
* tipo de produto (ex.: embalagem especial — ver `docs/domain.md`)
* região
* transportadora
* modalidade de envio

Nesta fase, o cálculo inicial é feito por `Shipping::Calculator`, sem dependência
de API externa: usa CEP, peso total dos itens e quantidade. O resultado preserva
transportadora, modalidade, valor e prazo estimado no `Shipment` associado ao
`SellerOrder` do artesão. Assim, frete e fulfillment já estão isolados por
vendedor, embora o primeiro lançamento aceite somente um vendedor por checkout.
O provedor é isolado para permitir a integração futura com Correios,
agregador ou transportadora privada quando essa decisão de negócio for tomada.

O produto possui peso e dimensões opcionais. O peso participa do cálculo; as
dimensões ficam registradas para o próximo provedor que exigir cubagem. CEP
inválido ou peso acima do limite de envio tornam o frete indisponível e impedem
a criação do pedido.

## SuperFrete — provedor de frete (2026-10-30)

O Melhor Envio só libera IP **fixo, exclusivo e brasileiro** (resposta do suporte
em 2026-10-30), e a Railway não tem região no Brasil nem IP de saída exclusivo.
A SuperFrete aceita a Railway: do mesmo IP que o Melhor Envio bloqueia, a API
respondeu `401` em JSON sem token. Documentação oficial:
`superfrete.readme.io`.

**Conexão do ateliê** (`SellerPortal::SuperfreteConnectionsController`,
`Marketplace::SuperfreteOauth`): OAuth 2.0, que a SuperFrete reserva a
"operações com múltiplas lojas" — credenciais de plataforma pedidas por
formulário, um par por ambiente, com o redirect `/painel/superfrete/callback`
idêntico ao cadastrado. Diferenças em relação ao Melhor Envio:

* a autorização é rota com hash no app web (`/#/auth/authorize?client_id&redirect_uri&state`),
  sem `response_type` nem `scope`; o `state` é opcional para eles e **exigido**
  aqui (`SellerPortal::SuperfreteConnectionsController`: digest na sessão, prazo
  de 10 minutos, comparação em tempo constante);
* o token **não expira** e não há refresh — e dá acesso à carteira que paga as
  etiquetas. Fica cifrado em `Seller#superfrete_access_token_ciphertext`; um
  `401` numa cotação vira o evento `shipping.provider_unauthorized` (o ateliê
  revogou do lado de lá) e o checkout segue com o frete dele. Desconectar na
  EloShop apaga o token, mas a documentação não fala de revogação: o painel
  orienta o ateliê a remover a integração também na SuperFrete;
* no **sandbox**, a troca do token vai para uma Cloud Function
  (`us-central1-sandbox-api-superfrete.cloudfunctions.net/...`), não para
  `sandbox.superfrete.com` — os endereços por ambiente ficam em constantes;
* a troca não devolve a conta: ela vem de `GET /api/v0/user` e fica gravada
  (`superfrete_account_id`/`_email`). Reconectar com outra conta avisa que as
  etiquetas passam a ser pagas por ela.

**Único provedor**: o Melhor Envio foi removido no mesmo dia (ver a nota em
"Etapa 1", abaixo). `Shipping::Providers.for` devolve a SuperFrete quando o
ateliê a conectou e a chave do ambiente está ligada.

**Cotação** (`Shipping::Providers::Superfrete`): `POST /api/v0/calculator` com
`services: "1,2,17"` (PAC, SEDEX, Mini Envios — Jadlog, Loggi e J&T exigem
ponto de coleta perto da origem e ficam de fora até haver demanda), produtos em
cm/kg e seguro em reais. Serviços com `has_error` são descartados.

**Quem decide o preço é o ateliê** (decisão de 2026-10-30): com frete definido
no produto, vale esse frete; a cotação só passa na frente quando o ateliê
escolhe no painel (`Seller#provider_quotes_preferred`, falso por padrão — os
termos dizem que o frete é definido pelo vendedor). Produto sem frete definido
usa a cotação antes da tabela interna; frete grátis vence sempre. A escolha
fica no cartão da SuperFrete, no ateliê.

**Cotação real verificada a partir da Railway (2026-10-30).** Com um token
manual de sandbox, `POST /api/v0/calculator` saindo do container de produção
(o mesmo IP que o Melhor Envio bloqueava) devolveu, de 01001-000 para
20040-020 com 0,5 kg: PAC R$ 23,51 em 2 dias e SEDEX R$ 34,57 em 1 dia,
`company.name` "Correios", `has_error: false` — o formato que
`Shipping::Providers::Superfrete` lê. O `price` já vem com o desconto da
SuperFrete aplicado (o campo `discount` só informa quanto foi). CEP de origem
que os Correios não reconhecem responde `400` com
`correios.origin_postcode`: a cotação cai no frete do ateliê sem avisá-lo —
melhoria futura. Credenciais OAuth de plataforma pedidas no mesmo dia pelo
formulário da SuperFrete (prazo de até 24 horas úteis); o formulário pede que o
redirect "aceite GET e retorne 200" — ver "Retorno do OAuth feito pelo
servidor da SuperFrete", abaixo.

**Credenciais recebidas em 2026-11-04**: a SuperFrete enviou o par de
produção e o de sandbox, e recusou o redirect de sandbox em `localhost`,
pedindo uma URL remota. Como não há ambiente de homologação, a decisão
(Uriel, 2026-11-04) foi validar direto com a credencial de produção — cotar
não gasta saldo e as vendas estão fechadas — e informar a mesma URL de
produção para o sandbox. Os valores vivem só nas variáveis da Railway.

**Retorno do OAuth feito pelo servidor da SuperFrete (2026-11-04).** No
primeiro teste em produção, o `GET /painel/superfrete/callback?code&state`
chegou do servidor dela (`user_agent` `axios`, IP do Google Cloud), não do
navegador do ateliê: sem sessão, o painel mandava para o login e nada era
gravado, e o navegador ficava parado na SuperFrete. A documentação só diz
"enviaremos para a redirect_uri ... com um GET", e o formulário pedia que o
redirect "aceite GET e retorne 200". Desde então:

* o `state` pendente fica no `Seller` (`superfrete_oauth_state_digest` e
  `_issued_at`, só o digest, índice único), não na sessão
  (`Seller#issue_superfrete_oauth_state!`);
* o retorno é público (`allow_unauthenticated_access`, com `rate_limit`),
  consome o `state` com um `UPDATE` condicionado ao digest — vale uma vez e por
  10 minutos (`Seller.claim_superfrete_oauth_state`) — e grava no ateliê dono
  dele;
* a troca do código envia também o `state`, como a documentação pede;
* responde **200** no sucesso, 400 com `state` inválido, 502 quando a
  SuperFrete falha e 503 com a cotação desligada, sempre com uma página
  simples que serve também a um navegador. O ateliê volta ao painel por conta
  própria e vê a conta conectada no cartão da SuperFrete.

Sem a sessão, um golpe de consentimento passa a ser possível (o ateliê de um
atacante recebendo a conta SuperFrete de quem autorizar pelo link dele): aceito
enquanto o token só cota, com condição registrada no ADR 005 para antes da
etiqueta.

**Conexão obrigatória para aprovar (decisão do Uriel, 2026-11-04).** Onde a
cotação está ligada (`Seller#superfrete_required?`, a mesma chave
`SHIPPING_REMOTE_QUOTES_ENABLED`), conectar a SuperFrete é etapa dos Primeiros
passos (`:superfrete`, entre a chave PIX e a primeira peça) e requisito de
`Seller#approve!` (`Seller#approval_requirements_met?`, também usado pela tela
do admin), para **todos** os ateliês: publicar já exige frete de entrega, então
não existe ateliê "só retirada" a dispensar. A regra **não** entra em
`Product#purchase_blocker`: quem já foi aprovado continua vendendo (vê a etapa
pendente e o aviso "quase pronta"), e uma pane da SuperFrete ou a chave
desligada não param a loja — com a chave desligada, a etapa some e a exigência
cai. "Conectado" é `Seller#superfrete_ready?`: ambiente certo e sem 401 desde a
conexão — um 401 na cotação grava `superfrete_revoked_at` e o painel pede para
reconectar. Conectar não obriga a usar a cotação: o ateliê segue escolhendo
qual frete o cliente paga.

O passo a passo fica em **Frete e entregas** (`/painel/frete`,
`SellerPortal::ShippingSettingsController`), no menu Configuração, no tour e
na aba "Frete" do celular; o cartão de conexão é o mesmo partial de Dados do
Ateliê (`superfrete_connections/_banner`). O "Como funciona" (aba Quem vende)
mostra a etapa na mesma condição.

**Resiliência e ambiente (2026-11-04, revisão de arquitetura antes de ligar a
cotação em produção):**

* **Disjuntor por ateliê** (`Shipping::Calculator::PROVIDER_COOLDOWN`, 1
  minuto). `OrdersController#new` cota uma vez por endereço do cliente, em
  série, e uma falha não fica em cache: com a SuperFrete lenta (estourando o
  timeout de 3 s + 5 s em vez de recusar), cada endereço e cada recarga
  esperavam de novo, e com 2 threads no Puma (o Solid Queue roda no mesmo
  processo) dois clientes no checkout paravam a loja inteira. Agora a primeira
  falha marca o ateliê em `Rails.cache` e, por um minuto, ele vai direto ao
  frete que definiu. É por ateliê porque `401` (token revogado) e CEP de
  origem inválido são falhas dele; numa queda geral, o primeiro cliente de
  cada ateliê ainda espera o timeout uma vez por minuto.
* **Ambiente da conexão.** O ateliê grava o ambiente (`superfrete_sandbox`) ao
  conectar, e a cotação segue esse registro. `Shipping::Providers.for` só cota
  quando ele bate com o configurado (`Seller#superfrete_environment_current?`,
  `Marketplace::SuperfreteOauth.sandbox?` como fonte única); senão o painel
  pede para reconectar. Sem isso, uma conexão feita no sandbox continuaria
  cotando preço de teste depois da troca para produção — e, na etapa da
  etiqueta, compraria etiqueta de teste para um pedido pago.
* **Chave do cache** inclui a conta conectada, o ambiente
  (`Superfrete#cache_scope`) e a versão de cada produto (`cache_version`):
  trocar de conta ou editar peso e medidas não reaproveita a cotação antiga.
* **Comportamento conhecido, sem correção por ora**: a opção escolhida é
  reencontrada por transportadora + serviço, não pelo preço. Se o cache de 30
  minutos expirar entre abrir o checkout e confirmar, o pedido grava o preço
  novo; o cliente vê o total antes de pagar. Corrigir (recusar e pedir nova
  escolha) só se aparecer reclamação.

**Etiqueta pelo painel** (2026-11-05) e **rastreio por webhook** (2026-11-11),
ver abaixo. Decisões e desenho no ADR 005, "Etapa 2 e 3 — decisões e desenho
(2026-11-05)".

### Etiqueta pelo painel (2026-11-05)

No detalhe do pedido pago que aguarda envio, o ateliê vê o cartão **Etiqueta
pela SuperFrete** ao lado do envio manual, que continua valendo
(`SellerPortal::ShippingLabelsController`, `/painel/orders/:id/etiqueta`).

1. **Pacote e serviço** (`/etiqueta/nova`): medidas sugeridas pelas peças, o
   ateliê corrige para a caixa real e cota. A tela mostra preço, prazo, as
   medidas finais (a SuperFrete arredonda) e, quando a etiqueta custa mais que o
   frete pago pelo cliente, a diferença que fica com o ateliê.
2. **Pedido** (`ShippingLabels::Request`): recota no servidor (o preço nunca vem
   do navegador), confere as pré-condições e grava a etiqueta em `draft`. A
   compra segue em job (`PurchaseShippingLabelJob`).
3. **Compra** (`ShippingLabels::Purchase`): cria o pedido na SuperFrete e grava o
   id **antes** de pagar; com o envio travado, confere de novo desistência e
   reembolso e paga. Depois de um resultado incerto (timeout, 5xx), o pagamento
   **nunca é reenviado**: a consulta do pedido decide, e enquanto a SuperFrete
   mostrar pendente a etiqueta fica "confirmando", com **Conferir de novo** e
   **Cancelar** no painel.
4. **Imprimir** pede um link novo à SuperFrete a cada clique (o PDF não é
   guardado; só `https` é aceito). **Cancelar** é só por clique do ateliê, antes
   da postagem, e o valor volta para a carteira dele.

Saídas que o ateliê sempre tem (QA de 2026-11-05):

* etiqueta em andamento (inclusive presa em `draft` ou `cart_created` porque o
  job morreu num deploy) mostra **Conferir de novo** e **Cancelar**;
* com o pedido reembolsado ou em reembolso, a etiqueta ativa continua no
  painel, só com **Cancelar**, para o valor voltar à carteira;
* se o pedido criado na SuperFrete sair **mais caro que o cotado**, a compra
  não paga: cancela o pedido lá e pede nova cotação;
* dois jobs para a mesma etiqueta em rascunho: o que perde a corrida cancela
  o pedido que criou lá, para não deixar pedido órfão.

Pré-condições (`ShippingLabels::Guard`): chave ligada, SuperFrete conectada no
ambiente certo, **e-mail da conta SuperFrete igual ao de um acesso do ateliê**
(condição de segurança do ADR 005), CPF de quem recebe no pedido, endereço de
origem e nome completo do responsável; com o envio travado, pedido pago
aguardando envio, sem reembolso integral em andamento, sem desistência aberta
e sem outra etiqueta ativa (índice único parcial no banco).

O estado vive em `ShippingLabel` (`draft → cart_created → purchasing →
purchased`, mais `cancelled` e `failed`), com transições por `UPDATE`
condicionado. A resposta crua da SuperFrete nunca é gravada:
`ShippingLabels::Client` extrai só id, status, rastreio, preço, serviço e link.
Timeouts: 8 s nas chamadas feitas durante a requisição do painel, 20 s no job.

**Limite de etiquetas antes da compra** (2026-11-11): ao abrir a tela de gerar
etiqueta, o sistema consulta a conta SuperFrete do ateliê (`GET /api/v0/user`,
`ShippingLabels::Client#label_limits`, que só extrai os dois números — a
resposta traz dados pessoais da conta) e mostra quantas etiquetas ele ainda
pode comprar. Com o limite zerado, a tela para antes de cotar e explica que é
preciso postar ou cancelar as pendentes. Se a consulta falhar, a tela segue
sem o aviso e a SuperFrete continua recusando a compra se faltar espaço.

**Quem paga a etiqueta é sempre a carteira SuperFrete do ateliê.** O sistema
só envia o comando de compra em nome dele, autorizado pela conexão OAuth; a
conta da plataforma não paga etiqueta de ninguém.

**Pendente — tentar o pagamento de novo quando o pedido está pendente**
(decisão do Uriel, 2026-11-11: só depois do teste em produção). Hoje, se a
resposta do pagamento se perde (timeout), o sistema consulta o pedido e, se a
SuperFrete o mostra pendente, **não** manda cobrar de novo: a etiqueta fica
"confirmando" até o ateliê clicar em **Conferir de novo** ou **Cancelar**. A
SuperFrete afirmou em 2026-11-11 que repetir o checkout de um pedido já pago
responde `409` "Pedido já comprado." sem cobrar de novo; com isso, o sistema
poderia repetir o comando sozinho quando a consulta disser "pendente". Antes de
mudar, o teste em produção deve provar a afirmação — comprar uma etiqueta,
repetir o checkout do mesmo pedido e conferir que a carteira do ateliê foi
debitada uma vez só —, porque o erro aqui seria uma cobrança dupla na carteira
do ateliê. O caso é raro (só com falha de rede no meio do pagamento) e hoje
não custa dinheiro, só um clique.

**Ligar em produção**: `SHIPPING_LABELS_ENABLED=true` na Railway, **depois** da
compra real verificada (saldo no sandbox ou uma etiqueta de produção). O que
ainda não foi exercitado contra a API: a resposta do checkout com saldo, o
rastreio devolvido nela e o estorno do cancelamento. O código de rastreio é
gravado na etiqueta e preenche o campo do envio manual; a postagem e a
entrega passam a vir do rastreio (abaixo), e o ateliê continua podendo marcar
à mão.

### Etiqueta e rastreio: o que o sandbox mostrou (2026-11-05)

Exercitado em `sandbox.superfrete.com` com token manual de integração, a partir
da estação local, com script descartável (fora do repositório). Os carrinhos de
teste foram cancelados e o webhook de teste apagado. A documentação oficial
diverge da API em vários pontos; vale o que está aqui.

* **`to.document` é obrigatório**: sem ele, `POST /api/v0/cart` responde `400`
  com `errors["to.document"]`. Telefone do destinatário pode ir `null`.
* **`service`** aceita inteiro (`1`) e também string (`"1"`).
* **Referência da EloShop:** `options.tags: [{tag, url}]` é guardado e volta no
  carrinho e na consulta do pedido. `tag`/`url` no topo do corpo são aceitos e
  **ignorados**.
* **Carrinho** devolve `{id, price, protocol, self_tracking, status: "pending", tags}`,
  sem debitar. A SuperFrete **ajusta as medidas** para o mínimo do serviço (pedido
  15×20 cm voltou 16×24 cm): a tela de compra deve mostrar as medidas finais.
* **Checkout sem saldo:** `409` com `message` "Sem saldo na carteira! ...". Repetir
  dá o mesmo `409`, sem efeito. Pedido cancelado: `409` "Este pedido está
  cancelado e não pode ser pago". **Id inexistente: `500`** com mensagem genérica
  — um `500` do checkout não prova que nada foi cobrado; a consulta do pedido
  decide.
* **Consulta** (`GET /api/v0/order/info/{id}`): id inexistente responde `400`
  ("Pedido não encontrado"). **A resposta traz dados pessoais da conta do ateliê**
  dentro de `service_calculated.data.user_config` (CPF, data de nascimento,
  e-mail, telefone, histórico de IPs): **nunca gravar nem registrar a resposta
  crua** — extrair só `id`, `status`, `tracking`, `price`, `service_id`.
* **`print.url`** existe já no carrinho pendente e muda a cada consulta: pedir na
  hora de imprimir, não guardar.
* **Cancelamento:** `POST /api/v0/order/cancel` responde `200` com
  `{"<id>": {"canceled": true}}`; repetir num pedido já cancelado dá `409` "Esse
  pedido não pode mais ser cancelado!" — tratar como já cancelado, conferindo
  pela consulta. O status volta como **`canceled`** (o webhook escreve
  `order.cancelled`).
* **Webhook:** `POST /api/v0/webhook` com o token da conta responde `201` com
  `secret_token` de 64 caracteres hexadecimais, **que não volta na listagem**
  (`GET /api/v0/webhook`); `DELETE /api/v0/webhook/{id}` responde `204`.
  Perdido o segredo, o webhook tem de ser recriado.
* **Conta nova tem limite de etiquetas:** `GET /api/v0/user` traz
  `limits.shipments` (pagas aguardando postagem) e `limits.shipments_available`
  (quantas ainda podem ser pagas). Segundo a SuperFrete (duas respostas em
  2026-11-11), é uma regra antifraude de conta nova (5 no nível 1), vale
  também em produção e se libera postando ou cancelando etiquetas. A conta
  **sobe de nível sozinha** conforme emite etiquetas e tem postagens
  confirmadas, e o limite cresce. Para parceiros homologados e ateliês que já
  começam com volume, a equipe de suporte/parcerias da SuperFrete pode
  **elevar o limite antes**, para o artesão não travar no início — vale pedir
  isso para os ateliês da EloShop no lançamento. O valor muda (a mesma conta de
  sandbox mostrou 5 em 2026-11-05 e 10 em 2026-11-11): ler da API, nunca
  fixar número. A tela de gerar etiqueta mostra o que resta e para antes de
  cotar quando o limite está zerado (ver "Limite de etiquetas antes da
  compra").
* **Checkout repetido:** o checkout é atrelado aos ids enviados em `orders`;
  num pedido já pago responde `409` "Pedido já comprado." e **não cobra de
  novo** (SuperFrete, 2026-11-11). Depois de um timeout, a conduta que ela
  recomenda é a que `ShippingLabels::Purchase` já segue: consultar
  `GET /api/v0/order/info/{id}` antes de qualquer nova tentativa —
  `released`/`generated` é pago (seguir o fluxo); pendente pode repetir o
  checkout com segurança. A EloShop é mais conservadora: depois de um
  resultado incerto só confere, não reenvia sozinha (o ateliê decide).
* **Id inexistente responde `500` no sandbox** em vez de `404`/`422` — a
  SuperFrete confirmou que é comportamento do sandbox. Em produção ela
  recomenda validar a existência do pedido antes do checkout; a EloShop só
  paga o id que acabou de criar e gravar, e continua tratando `500` como
  incerto.
* **Recarga PIX do sandbox não funciona:** a SuperFrete confirmou em
  2026-11-11 um bug para inserir saldo no sandbox e orientou seguir o teste
  **por produção**. A compra com saldo, o código de rastreio e o estorno do
  cancelamento ficam para o teste em produção.

### Rastreio por webhook (2026-11-11)

Respostas da SuperFrete em 2026-11-11 e guia oficial
(`developers.superfrete.com/guias/webhooks`):

* o token **OAuth** de cada ateliê tem escopo sobre a conta dele e registra o
  webhook nela (`POST /api/v0/webhook` com `Authorization: Bearer
  {access_token}`); o modelo é por conta (user), não existe webhook global do
  app OAuth com o `user_id` no payload, então cada conta tem o seu, com o seu
  `secret_token`. A URL pode ser a mesma para todos (ou carregar um
  identificador da loja): a EloShop põe uma chave aleatória do ateliê no
  caminho;
* `X-ME-Signature` é o HMAC-SHA256 do **corpo bruto** (bytes exatamente como
  enviados) com o `secret_token`, em **hexadecimal minúsculo de 64
  caracteres**, sem prefixo (nada de `sha256=`);
* não há id de evento: a repetição se evita pelo par evento + id do pedido;
* os eventos podem chegar fora de ordem ou pular etapas (`order.posted` nem é
  enviado se o pacote já foi entregue), e **uma notificação que falhou pode não
  ser reenviada** — a recomendação é consultar os pedidos em aberto.

Como ficou:

1. **Registro** (`ShippingLabels::Webhook`, em `RegisterSuperfreteWebhookJob`):
   ao conectar a SuperFrete e depois da primeira etiqueta comprada, se ainda
   não houver. Cria o novo antes de apagar o antigo e grava no `Seller` o id, o
   segredo cifrado e uma chave aleatória (`superfrete_webhook_key`) que vai na
   URL `/webhooks/superfrete/:key`. Desconectar apaga o webhook lá (se
   conseguir) e limpa os três campos. Só com `SHIPPING_LABELS_ENABLED`.
2. **Recebimento** (`SuperfreteWebhooksController`): acha o ateliê pela chave,
   confere a assinatura em tempo constante (chave desconhecida e assinatura
   errada respondem igual, `401`), grava `ShippingLabelEvent` só com os campos
   usados (índice único em pedido + evento) e responde `200`; o processamento
   é em job. Notificação de pedido que não é etiqueta do próprio ateliê é
   ignorada.
3. **Aplicação** (`ShippingLabels::Track`): `posted` marca o envio como
   enviado com o rastreio da etiqueta; `delivered` marca enviado (se faltar) e
   entregue — a entrega confirmada pela transportadora fecha o envio (decisão
   do Uriel, 2026-11-11), e o aviso ao comprador diz que foi a transportadora;
   `cancelled` cancela a etiqueta ainda não postada. Vale o status informado,
   não a ordem de chegada; repetir não avisa de novo.
4. **Postagem que o envio recusaria** (desistência aberta, reembolso integral
   em andamento, pedido reembolsado): a etiqueta guarda a postagem/entrega, o
   envio não muda, e a equipe e o ateliê recebem **um** aviso
   (`ShippingLabelMailer#needs_attention`) — o pacote já está com a
   transportadora; uma pessoa decide (decisão do Uriel, 2026-11-11).
5. **Conferência periódica** (`ReconcileShippingLabelsJob`, de hora em hora):
   consulta as etiquetas compradas e ainda não entregues, até 60 dias depois
   da compra, e passa o resultado pelo mesmo `Track`. Cobre a notificação
   perdida e quem ainda não tem webhook.

## Endereço de origem do ateliê

Desde 2026-09-06 o `Seller` tem endereço de origem (`origin_zip_code`,
`origin_street`, `origin_number`, `origin_complement`, `origin_neighborhood`,
`origin_city`, `origin_state`), editável pelo vendedor em `/painel/atelie`. É
de onde a peça é despachada — nenhum cálculo real de frete funciona sem o CEP
de origem, qualquer que seja a transportadora escolhida.

Os campos são **opcionais** por ora: os vendedores já cadastrados não os têm, e
exigi-los invalidaria o catálogo deles. Mas o preenchimento é tudo-ou-nada
(`Seller#origin_address_started?`): meio endereço não despacha nada. O CEP é
normalizado para 8 dígitos, como o CEP de destino que o `Shipping::Calculator`
já recebe.

`Seller#origin_address_complete?` responde se o ateliê está pronto para
despachar. **Tornar o endereço obrigatório é decisão para quando o frete real
for ligado** — provavelmente como pré-requisito de aprovação do vendedor, o que
exige backfill dos existentes.

Regras de frete não devem ser implementadas diretamente em controllers — devem ficar isoladas no domínio de Shipping.

**Provedor definido em 2026-09-06: Melhor Envio** — ver o **ADR 005**
(`docs/decisions/005-shipping-provider.md`), que registra por que ele foi
escolhido, o que a documentação dele confirma e como a integração se divide em
três etapas.

### Etapa 1 — cotação real (implementada em 2026-09-07)

> **Melhor Envio removido em 2026-10-30.** O suporte respondeu que só libera IP
> fixo, exclusivo e brasileiro, que a Railway não oferece; a integração nunca
> cotou em produção. Provider, OAuth, conexão no painel e as colunas
> `melhor_envio_*` saíram do código (o histórico fica no git). O que segue é
> registro do que foi feito e aprendido; o provedor atual está em
> "SuperFrete", acima. Continuam valendo as regras do `Shipping::Calculator`
> descritas aqui (fallback, cache, escolha por id, frete grátis).

Cada artesão conecta a própria conta do Melhor Envio pelo painel
(`/painel/atelie`), por OAuth2, no mesmo arranjo já usado para o Mercado Pago:
tokens cifrados em `Seller`, renovados sob lock antes de vencer
(`Marketplace::MelhorEnvioOauth`, `Marketplace::MelhorEnvioAccessToken`). Não
existe conta única da plataforma cotando por todos — a carteira pré-paga é de
quem despacha. Diferenças em relação ao OAuth do Mercado Pago, confirmadas na
documentação oficial: **sem PKCE**, `client_id` numérico, e a resposta do
token **não traz identificador de conta**, então não há como validar que um
token renovado pertence à mesma conta; o refresh token já está escopado ao
vendedor no banco.

`Shipping::Calculator` deixou de ser uma tabela e passou a ser o orquestrador:

* cota em `Shipping::Providers::MelhorEnvio` quando o vendedor conectou a conta
  **e** tem CEP de origem;
* **cai na tabela interna** (R$ 15 + R$ 5/kg) quando não conectou, quando o
  provedor falha, quando estoura o timeout ou quando nenhuma opção sobra. O ADR
  é explícito: uma venda com frete estimado é melhor que uma venda perdida — a
  tabela não deve ser deletada;
* guarda a cotação por 30 minutos em `Rails.cache`, chaveada por origem,
  destino e itens: trocar de endereço no checkout repete a mesma pergunta, e o
  rate limit do Melhor Envio não é documentado.

**Provedor por ateliê e chave por ambiente (2026-10-30).** O `Calculator` não
conhece mais o Melhor Envio pelo nome: pergunta a `Shipping::Providers.for(seller)`
qual provedor o ateliê conectou, e todo erro de provedor é um
`Shipping::Providers::Unavailable` (fallback, nunca erro de checkout). As
cotações externas obedecem a `config.x.shipping.remote_quotes_enabled`: ligada
fora de produção; em produção só com `SHIPPING_REMOTE_QUOTES_ENABLED=true` —
desligada, o lançamento usa o frete do ateliê, e um ateliê conectado a um app de
sandbox não passa a cobrar preço de teste porque um provedor começou a aceitar
as chamadas. Com a chave desligada a conexão pelo painel também é recusada.
`Checkout::CreateOrder` cota **antes** de abrir a transação: dentro dela, a
chamada externa rodaria com os produtos travados (`lock!`), prendendo uma peça
única para o próximo comprador enquanto a rede responde. O frete não depende do
que a trava protege, e o valor continua recalculado no servidor pelo id da
opção.

`#quotes` devolve **a mais barata e a mais rápida** (uma só quando coincidem);
`#call(quote_id:)` reencontra a escolhida. Os timeouts são curtos (3s para
conectar, 5s para ler) porque isso roda dentro do checkout.

Enquanto o WAF do Melhor Envio impede a cotação a partir da Railway, a ordem de
resolução é: cotação externa válida; na ausência dela, frete fixo dos produtos;
por fim, tabela interna. A retirada gratuita, quando habilitada, é acrescentada
como opção independente em todos esses casos. O endereço do cliente ainda é
obrigatório no MVP, inclusive para retirada, porque o checkout e o pedido
preservam o mesmo snapshot de endereço.

**Frete grátis por produto** (`Product#free_shipping`, decisão de negócio
2026-09-24): toggle por produto, independente de `fixed_shipping` estar
configurado — um item marcado contribui `0` centavos à soma do frete do
pedido, mesmo sem valor fixo definido. É uma **promessa do vendedor ao
cliente**, então vence mesmo havendo cotação real do Melhor Envio disponível
(ao contrário do frete fixo, que só entra na ausência de cotação remota). O
custo é **absorvido pelo vendedor**: como a comissão da plataforma já incide
sobre `subtotal - discount` sem frete (CLAUDE.md §34), zerar o frete apenas
reduz `seller_amount_cents` — nenhuma lógica extra de comissão foi
necessária. Não resolve a segunda pergunta pendente abaixo (quem absorve a
diferença de um frete real acima do estimado): essa continua em aberto.

**O cliente escolhe por identificador, nunca por preço.** O formulário envia
`shipping_quote_id` (derivado de transportadora + serviço), e
`Checkout::CreateOrder` recota no servidor e reencontra a opção — uma opção que
não está mais entre as ofertadas é recusada, não substituída. É a mesma regra
que já valia para preço de produto e desconto (ver `docs/checkout.md`).

**Verificado no sandbox, a partir do ambiente local (2026-10-28); produção
segue bloqueada.** O WAF do provedor bloqueia o IP de saída da Railway com
`E-WAF-0003` antes de a requisição chegar à API — ver o parágrafo de
2026-09-12 no `ROADMAP.md`; o pedido de liberação do IP é o ticket nº 2086648,
aberto em 2026-10-28. O bloqueio é só desse IP, então a integração foi
exercitada da estação de desenvolvimento: OAuth completo (conectar, trocar o
código, gravar os tokens cifrados com `melhor_envio_sandbox`), cotação real
(Correios PAC e SEDEX, origem Vitória/ES, para ES, SP e AM) e um checkout até
o pedido pago, com o frete escolhido gravado no `Shipment`. Os testes
automatizados seguem stubando HTTP e cobrindo o contrato do adapter.

Para repetir o teste local:

* **Uma aplicação de sandbox só para desenvolvimento**, separada da `11947`
  (cujo retorno aponta para produção). O cadastro do Melhor Envio exige
  `https://` nas URLs, então o retorno passa por um túnel:
  `cloudflared tunnel --url http://localhost:3000`. A URL
  `*.trycloudflare.com` muda a cada execução, e a aplicação e o `.env`
  precisam acompanhar.
* No `.env`: `MELHOR_ENVIO_CLIENT_ID`, `MELHOR_ENVIO_CLIENT_SECRET`,
  `MELHOR_ENVIO_REDIRECT_URI=https://<túnel>/painel/melhor-envio/callback` e
  `MELHOR_ENVIO_SANDBOX=true`.
* Em `config/environments/development.rb`, uma linha **local, que não vai
  para o repositório**: `config.hosts << ".trycloudflare.com"` — sem ela o
  Rails responde "Blocked host".
* O botão de conexão está escondido pelo aviso do #273, mas a rota segue
  ativa: abra `/painel/melhor-envio/conectar` direto, pelo endereço do túnel
  (a sessão precisa estar no mesmo host do retorno).
* O banco local nasce em pré-cadastro: abra as vendas pelo dashboard do admin
  ou com `PlatformSetting.open_sales!`.
* A cotação fica 30 minutos em cache; troque o CEP ou limpe o cache para
  repetir.

O teste revelou um defeito do checkout, corrigido no mesmo dia: a lista de
modalidades era montada só para o primeiro endereço, e trocar de endereço
deixava o resumo com o frete do anterior (o servidor recotava e cobrava o
certo, mas o cliente via outro valor). Cada endereço tem agora o próprio grupo
de modalidades.

O código de rastreio **não** vem desta etapa: ele só existe depois da compra
da etiqueta (Etapa 2). Até lá, o artesão compra a etiqueta no site do Melhor
Envio e informa o código no detalhe do pedido (ver "Acompanhamento
operacional do MVP").

`TODO — DECISION REQUIRED`: segue pendente, e trava apenas as Etapas 2 e 3
(etiqueta e rastreio), **quem absorve a diferença** quando o frete real sai mais
caro que o cobrado no checkout. Frete grátis por produto (a partir de qual
valor e por conta de quem) já foi decidido — ver acima.

## Embalagem

Produtos artesanais podem ter necessidades especiais de embalagem (peso da embalagem, dimensões, fragilidade, necessidade de proteção, instruções especiais). Este domínio não deve ser adicionado até existir uma necessidade real e concreta — não faz parte do MVP nem está agendado em uma fase específica do roadmap ainda.

`TODO — DECISION REQUIRED`: se e quando embalagem especial se tornar uma necessidade real do negócio, isso deve ser adicionado ao `ROADMAP.md` como uma fase própria antes de ser implementado.

## Rastreamento

`Shipment` é criado com o `SellerOrder` em status `pending`, preservando transportadora,
modalidade, preço e prazo estimado. Código de rastreamento e transições de envio
serão preenchidos quando houver integração operacional com a transportadora.

### Acompanhamento operacional do MVP

Enquanto etiqueta e rastreamento automático não existem, o artesão atualiza a
entrega manualmente no detalhe do pedido em `/painel/orders/:id`. A linha do
tempo usa os campos que já pertencem a `Shipment`:

```text
Pedido recebido → Em preparação → Enviado → Entregue
```

Para retirada no ateliê, as duas últimas etapas são “Pronto para retirada” e
“Retirado”. O pedido só pode avançar depois da confirmação do pagamento, não
pode pular a etapa de envio/pronto para retirada e grava `shipped_at` e
`delivered_at`. Pedidos cancelados ou totalmente reembolsados não avançam.

Enquanto a integração com o Melhor Envio está bloqueada, o detalhe do pedido
orienta o artesão a comprar a etiqueta no site do Melhor Envio com a própria
conta, com remetente e destinatário explícitos, e a colar o código de rastreio
aqui. O formulário do produto orienta a simular o envio no mesmo site para
definir as duas faixas.

O código de rastreio digitado é normalizado (sem espaços, em maiúsculas), só
aceita letras, números e hífen e não pode repetir o de outro pedido — o índice
único é global. Formato inválido e código repetido recebem a mesma mensagem,
para a resposta não confirmar que o código existe em pedido de outro ateliê
(`Shipment::InvalidTrackingCode`).

Essa atualização manual continua valendo para quem envia sem a etiqueta da
EloShop. Para a etiqueta da SuperFrete, o rastreio por webhook (acima) usa as
mesmas transições de `Shipment` e os mesmos avisos (`ShipmentNotifications`).
