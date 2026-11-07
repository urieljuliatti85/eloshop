# ADR 007 — Distribuidores de insumos

## Status

Proposed — desenho registrado em 2026-10-31, **sem implementação**. As decisões
de escopo estão tomadas; a implementação só começa depois do acompanhamento dos
primeiros ateliês e com a SuperFrete funcionando de forma estável em produção
(ver "Dependências"); a meta de abertura da vertical é dezembro de 2026. A
revisão de arquitetura de 2026-11-07 conferiu o desenho contra o código e as
decisões que ela levantou foram tomadas no mesmo dia (ver "Decisões da revisão
de arquitetura"). Restam pendentes duas perguntas jurídicas (nota fiscal e
arrependimento) e uma confirmação com o Mercado Pago — ver "Decisões
pendentes".

**Fase 25 antecipada (2026-11-07, decisão do Uriel):** nenhum distribuidor
vende antes das Fases 26 a 28, então a fundação entrou antes dos
pré-requisitos. O PR #329 trouxe os dados e as proteções; o PR seguinte, o
cadastro (`/atacado/cadastro`), a porta de login (`/atacado/entrar`) e o painel
(`/atacado/painel`, `DistributorPortal`). O cadastro fica atrás de
`config.x.distributors.signup_enabled`: ligado fora de produção, desligado em
produção até o advogado revisar o rascunho dos termos do distribuidor
(`DISTRIBUTOR_SIGNUP_ENABLED=true` liga). Login e painel não dependem da chave.
O papel é perguntado num lugar só, `User#portal` (`:admin`, `:atelier`,
`:distributor`). A conexão do Mercado Pago dos dois tipos passa por
`SellerPortal::MercadoPagoConnectionsController`, porque o redirect URI
registrado no provedor é um só; é o único controller de `/painel` que aceita
distribuidor, e ele devolve cada um ao próprio painel. A SuperFrete do
distribuidor fica para a Fase 28, e até lá a aprovação dele não a exige
(`Seller#superfrete_required?` só vale para ateliê).

## Contexto

A EloShop é um marketplace em que artesãos vendem as próprias peças ao
consumidor final (ADR 004). O negócio quer abrir uma segunda ponta: o
**Distribuidor**, um vendedor atacadista de **insumos** (fios, tecidos, argila,
tintas, ferragens, embalagens) cujo comprador principal é o próprio artesão.

O código já tem quase tudo o que um vendedor precisa — `Seller`, OAuth com o
Mercado Pago (KYC feito pelo provedor), split com `application_fee`, painel
escopado por `current_seller`, aprovação/suspensão pelo admin, termos
comerciais, `SellerOrder`, comissão em inteiros e reembolso proporcional. O que
o distribuidor tem de diferente é a natureza do produto e da venda:

* insumo industrializado, não peça feita à mão;
* unidade de venda variada (pacote, metro, kg, rolo, caixa);
* pedido mínimo e preço por faixa de quantidade;
* frete volumoso/pesado, em que a tabela interna não serve;
* comprador que, quando formalizado, costuma precisar de nota fiscal.

## Decisão

**Escopo — só insumos.** Produto acabado para revenda fica fora: revenda de
terceiros contradiz o ADR 004 e a identidade "feito à mão" do catálogo.

**Modelagem — o distribuidor é um `Seller`, não uma entidade nova.**
`Seller#kind` (`atelier` / `distributor`) distingue os dois. Uma entidade
separada duplicaria OAuth, split, aprovação e antifraude sem que as regras
divergissem o bastante para justificar. O tipo é fixo depois do cadastro.

**Conta — o distribuidor é sempre um usuário novo.** Um ateliê não vira
distribuidor nem acumula os dois papéis: quem quiser vender insumos cria outro
`User`, com outro e-mail, ligado a outro `Seller`. Isso preserva a regra atual
de um `User` para um `Seller` e mantém pedidos, repasses e termos de cada
negócio separados.

**Painel — dedicado ao distribuidor.** Ele não usa o painel do ateliê
(`/painel`). Recomendação técnica: um namespace próprio (ex.:
`DistributorPortal`, em `/atacado/painel`) com porta de login própria (ex.:
`/atacado/entrar`), seguindo o padrão que já separa admin e vendedor. Cada porta
só aceita o tipo correspondente, com a mesma mensagem genérica de erro, e o
escopo continua vindo de `Current.user.seller`, nunca da URL. O
`SellerPortal::BaseController` passa a recusar distribuidores, e o novo
painel recusa ateliês.

**Aprovação — mesma análise do ateliê.** Conexão `live_mode` com o Mercado Pago
e confirmação explícita do KYC pelo admin antes de `Seller#approve!`;
desconectar volta para `pending` e para de vender, mas continua na vitrine
(aprovar marca a vitrine — mesmo comportamento do ateliê; não reintroduzir a
despublicação em `disconnect_mercado_pago!`).

**Comprador — qualquer pessoa, com a conta de `Customer` que já existe.** O
artesão compra insumo como qualquer cliente; não há área restrita nem preço
exclusivo. O vínculo `Customer ↔ Seller` ("artesão comprador verificado") fica
como evolução, só se surgir um benefício concreto para ele (desconto exclusivo,
recompra rápida, histórico no painel) — ele mexe em autenticação, que é área
sensível, e com preço público perde seu principal motivo.

**Preço — público, incluindo a tabela de faixas.** Favorece SEO (buscas de
atacado são reais e preço atrás de login não entra nos dados estruturados),
transparência (§60) e simplicidade (dispensa regra de visibilidade por papel).
A faixa aplicada é sempre resolvida no servidor e gravada no snapshot do
`OrderItem` (§21, §23).

**Comissão — 15%**, a mesma base de cálculo do ateliê (produtos após descontos,
sem frete), resolvida por `Seller#platform_fee_rate_bps` e gravada no
`SellerOrder` na compra. Taxa de lançamento: **8% por 3 meses**, com a mesma
regra do ateliê — contados do mais tardio entre `Seller#approved_at` e
`PlatformSetting.sales_opened_at`, o que para o distribuidor equivale, na
prática, à data de aprovação. Não há regra nova: o distribuidor usa o cálculo
que já existe (`LAUNCH_PLATFORM_FEE_RATE_BPS`). Dezembro de 2026 é a meta de
abertura da vertical, não uma janela de calendário para a taxa. Os termos
comerciais do distribuidor nascem novos e já devem descrever essa contagem
(os do ateliê ainda dizem "contados da data de aprovação", ver `CLAUDE.md`).

**CNPJ — opcional.** A EloShop continua sem coletar documentos (§34): a
identidade fica com o KYC do Mercado Pago, e nota fiscal/impostos seguem
responsabilidade do vendedor. Para o comprador formalizado saber antes de
comprar, a recomendação é o distribuidor **declarar publicamente se emite nota
fiscal**, exibido na loja e no produto, sem validação pela plataforma. Se essa
declaração será obrigatória depende de consulta jurídica.

**Vitrine — separada do catálogo artesanal.** Insumos ficam em `/insumos`, fora
de `/produtos`, da busca e do SEO das peças. `Material` e `Technique` servem de
ponte ("insumos para crochê").

**Pedido mínimo — só quantidade mínima por produto.** Cada insumo define a
quantidade mínima de compra (padrão 1, sem mínimo), validada item a item. Não
há valor mínimo por pedido: ele levantaria regras novas (cupom antes ou depois,
frete dentro ou fora, carrinho que cai abaixo do mínimo) e só entra se os
distribuidores pedirem.

**Checkout — a limitação de um vendedor por pedido continua.** O split público
do Mercado Pago é 1:1 (ADR 004); compra de insumo costuma vir de um fornecedor
só, então a limitação não pesa aqui.

## Decisões da revisão de arquitetura (2026-11-07)

A revisão conferiu este desenho contra o código e achou premissas de "loja de
peças artesanais" que o desenho acima não tratava. As decisões abaixo seguem a
recomendação técnica da revisão e foram aprovadas pelo Uriel em 2026-11-07.

**Peso e volumes — um volume por pedido, até 30 kg.** `Shipping::Calculator`
recusa pedido acima de 30 kg (`MAX_WEIGHT_GRAMS`) antes de cotar, inclusive a
retirada, e cotação, etiqueta e `Shipment` (`has_one` no `SellerOrder`) assumem
um único volume. A vertical abre com esse limite, **exibido na PDP e no
carrinho** ("até 30 kg por pedido"), e mede quantos carrinhos esbarram nele.
Vários volumes por pedido (cotação por pacote, etiqueta e rastreio por volume)
só entram com essa demanda medida, porque mexem no fluxo de etiqueta.

**CPF — único por tipo de vendedor.** Hoje `cpf_hash` é único entre todos os
`Seller` (índice parcial no banco), o que impediria a artesã de abrir uma
distribuidora com o próprio CPF. O índice passa a ser `(cpf_hash, kind)`,
preservando o antifraude dentro de cada tipo. **A suspensão vale para os dois
tipos:** suspender um `Seller` suspende o outro do mesmo CPF, para que a
separação não vire caminho de recadastro. A conta do Mercado Pago continua
única por `Seller` (`mercado_pago_user_id`); se o mesmo CPF pode ter uma
segunda conta no provedor depende do Mercado Pago (ver "Decisões pendentes").

**Frete sem cotação — vale o frete fixo do distribuidor, nunca a tabela
interna.** Com a cotação desligada ou o disjuntor aberto, o checkout do
distribuidor usa o frete fixo que ele definiu no produto. Sem frete definido, o
insumo não é vendido: a tabela interna (R$ 15 + R$ 5/kg) não representa carga
pesada e o prejuízo seria do vendedor. A compra de insumo (Fase 27) não abre
antes dessa regra (Fase 28): as duas sobem juntas, ou a 28 antes.

**Faixas de preço.**

* A faixa é resolvida pelo **total do produto** no carrinho, somando as
  variantes (5 cores do mesmo fio contam juntas), não por linha.
* A faixa é definida no produto e aplicada sobre o preço da variante.
* A unidade de venda é um **múltiplo inteiro** ("pacote de 50 cm", "saco de 1
  kg"): quantidade, estoque e centavos continuam inteiros no sistema inteiro.
* A faixa é modelada só pela quantidade mínima, com índice único em
  `(product_id, min_quantity)` e sem limite superior, o que torna a
  sobreposição impossível por construção.
* A faixa é resolvida dentro de `CartItem#unit_price_cents`, que o checkout já
  usa sob trava; o servidor continua sendo a única fonte do preço.
* **Formato (decisão do Uriel, 2026-11-07): desconto em %** — "a partir de N
  unidades, X% de desconto", em basis points (`ProductPriceTier#discount_bps`),
  com **teto de 50%** (decisão de 2026-11-07, para o preço nunca chegar perto
  de zero), porque as variantes podem ter preços diferentes e um preço
  fixo por faixa não teria como valer para todas. O preço da unidade com a
  faixa é `preço × (10.000 − desconto) / 10.000` em centavos inteiros,
  arredondado para baixo (a sobra de menos de um centavo fica com o
  comprador). As faixas começam acima da quantidade mínima, têm desconto
  crescente e são no máximo cinco por produto; a própria faixa confere as
  vizinhas e trava a linha do produto ao salvar, para duas faixas gravadas ao
  mesmo tempo não passarem contraditórias. Quantidades (mínimo e faixas) vão
  até 100.000, também como constraint no banco.
* **Unidade (decisão de 2026-11-07): lista fixa e descrição** — unidade,
  pacote, metro, quilo, rolo ou caixa (`Product#sale_unit`), mais um texto
  curto e opcional do que vem nela (`sale_unit_detail`, até 60 caracteres:
  "pacote com 100 g").
* **Navegação de `/insumos` (decisão de 2026-11-07): material e técnica**, as
  tabelas que já existem; uma árvore de categorias de insumo só entra se os
  distribuidores pedirem.
* **Mínimo e estoque:** o mínimo conta o produto inteiro, somando as variantes
  ativas, e mínimo maior que o estoque é `Product#purchase_blocker`
  `:below_minimum_stock`, na fonte única de disponibilidade.

**Cupom da plataforma — só para ateliê.** Hoje o cupom não tem escopo de
vendedor e o desconto sai do repasse de quem vende (`seller_amount_cents =
total - comissão`, e a comissão incide sobre `subtotal - desconto`). Num
pedido de insumo, que é maior e tem margem mais apertada, um cupom pensado para
peça artesanal tiraria do distribuidor um valor que ele não aceitou. O cupom
ganha escopo por tipo de vendedor, com padrão "só ateliê", falhando fechado
como a vitrine. Que o desconto sai do repasse do ateliê já é a regra hoje e
passa a estar escrito em `docs/checkout.md`; levá-la ao texto dos
`SellerTerms` do ateliê fica para a revisão com o advogado, que também decide
a redação da contagem da taxa de lançamento (ver `CLAUDE.md`).

### Requisitos técnicos da mesma revisão

Não são decisões de negócio, mas mudam o plano das fases:

* **Vitrine fail-closed (Fase 25, antes da primeira aprovação).**
  `Product.publicly_visible` e `Seller.publicly_listed` alimentam cerca de 20
  superfícies públicas (`/produtos`, home, busca, sitemap, API, `/artesaos`,
  `AnnounceSalesOpeningJob`). Sem filtro, o primeiro distribuidor aprovado
  aparece em todas. Esses escopos passam a significar "ateliê", a vitrine de
  insumos ganha um escopo próprio, e um teste de guarda (como o
  `spec/guards/sales_opening_guard_spec.rb`) ou request specs por superfície
  impedem regressão.
* **Termos versionados por tipo (Fase 25).** `SellerTerms::VERSION` é único:
  o aceite dos termos do distribuidor falharia em
  `SellerTermsAcceptance.current_for?` e nos contadores de "em risco" do
  admin.
* **Papel em um lugar só (Fase 25).** As checagens de `seller?` estão em cerca
  de sete pontos (`Authentication#default_authenticated_url`,
  `SellerPortal::BaseController`, `SellerPortal::SessionsController`,
  `SellerPortal::TermsController`, `_header.html.erb`, `OrderMessage`). Cada
  uma passa a perguntar o tipo; o cadastro do distribuidor reaproveita o
  `rate_limit` e o Turnstile do cadastro do ateliê.
* **Quantidade mínima na fonte única (Fases 26 e 27).** Com mínimo maior que
  o estoque, o produto continuaria "disponível" sem poder ser comprado. O
  mínimo entra em `Product#purchase_blocker` (e na variante), e na
  revalidação sob trava de `Checkout::CreateOrder`.
* **Nenhuma afirmação de "feito à mão" para insumo (Fase 26).** A meta
  description padrão (`SeoHelper#product_meta_description`) diz "peça
  artesanal feita à mão" quando o produto não tem descrição — falso para insumo
  e vetado pelo §33. O texto padrão passa a depender do tipo de vendedor, e os
  e-mails e jobs que falam em "ateliê"/"artesão" (como o aviso de abertura das
  vendas) ganham a versão do distribuidor.
* **Unidade e faixas nos dados públicos (Fase 26).** A API (`price_cents` =
  `starting_price_cents`) e o JSON-LD `Product` publicam um preço só. Passam a
  levar a unidade de venda e as faixas (`priceSpecification` com quantidade de
  referência no JSON-LD; contrato da API regenerado pelo rswag).

## Endereços públicos do distribuidor (2026-11-07)

Decisão do Uriel, no mesmo formato do ateliê (tipo de vendedor › loja › item)
e fora de `/artesaos`, para não misturar com o catálogo nem com o SEO das
peças:

| | Ateliê | Distribuidor |
|---|---|---|
| Lista | `/artesaos` | `/distribuidores` |
| Loja | `/artesaos/:slug` | `/distribuidores/:slug` |
| Produto | `/artesaos/:slug/produtos/:produto` | `/distribuidores/:slug/insumos/:produto` |
| Vitrine geral | `/produtos` | `/insumos` |

O slug sai do nome no cadastro e é único entre ateliês e distribuidores
juntos (`Seller#slug`), então os dois prefixos nunca disputam o mesmo
endereço, e o slug não muda quando o nome muda, como no ateliê. As páginas
entram na Fase 26; até lá o endereço fica reservado e é mostrado no cadastro e
no painel, sem página no ar. Insumo nunca é servido em `/artesaos/...`
(guarda em `spec/requests/distributor_storefront_guard_spec.rb`).

**Esconder vale para o distribuidor (2026-11-07).** Como no ateliê, o admin
tira a loja e os insumos do ar sem suspender a conta (por exemplo, durante a
análise de uma denúncia).

**Vitrine do pré-cadastro também para o distribuidor (2026-11-07).** Como no
ateliê, o admin pode liberar o distribuidor pendente na vitrine
(`Seller#showcase!`), para os artesãos verem a loja e os insumos antes da
aprovação, sem o Mercado Pago; vender continua exigindo a aprovação. A
visibilidade é a mesma regra do ateliê, em lista própria:
`Seller.supply_listed` (aprovado, ou pendente liberado, nunca escondido ou
suspenso), par de `Seller.publicly_listed`, que continua só de ateliê. As duas
listas nunca se misturam. Os botões de liberar e de esconder já estão na ficha
do admin, e o painel do distribuidor diz se a vitrine foi liberada; as marcas
passam a ter efeito público quando a vitrine de insumos for ao ar (Fase 26,
PR C), que mostra só `supply_listed`. Isso também responde à dúvida de
`approve!` gravar `showcased_at` no distribuidor: a loja segue a regra do
ateliê.

## Painel do distribuidor reaproveitando o do ateliê (2026-11-07)

Revisão de arquitetura antes de montar o painel; decisão do Uriel pela opção
recomendada:

* **As telas compartilhadas** (Primeiros passos, endereço de origem, guias do
  Mercado Pago e da chave PIX, avisos) **entram no painel do distribuidor por
  subclasse em `DistributorPortal`**, montadas em `/atacado/painel` com o
  layout dele. O `/painel` continua só de ateliê; a conexão do Mercado Pago é
  a única exceção, porque o redirect URI registrado no provedor é um só.
* **Caminhos por tipo num lugar só:** `PanelPaths#panel_path(:tela)` monta
  `seller_*` ou `distributor_*` conforme o vendedor. As telas compartilhadas e
  os redirecionamentos delas usam o helper; um link fixo em `seller_*_path`
  levava o distribuidor a `/painel`, que o devolvia ao painel dele, e a
  jornada quebrava em silêncio. Rota que o painel do distribuidor não tem
  falha alto (NoMethodError).
* **Etapas de entrada por tipo, no model:** `Seller#getting_started_steps` do
  distribuidor é endereço → Mercado Pago → chave PIX → aprovação; "primeiro
  insumo" entra com o PR B da Fase 26 e "SuperFrete" com a Fase 28. O admin
  mostra o distribuidor aprovado como "aguardando o cadastro de insumos".
* **Guarda:** `spec/guards/distributor_portal_access_guard_spec.rb` lista os
  controllers de `/painel` que aceitam distribuidor (hoje só a conexão do
  Mercado Pago) e falha se a lista crescer sem revisão.
* **Celular:** as abas de baixo do painel do ateliê
  (`layouts/_seller_mobile_tabs`) já recebem a lista de abas e são
  reaproveitadas inteiras; o tour guiado fica fora do painel do distribuidor
  até ele ter as próprias telas.

## Decisões pendentes

1. **Declaração de emissão de nota fiscal** — obrigatória ou opcional; aguarda
   consulta jurídica, junto com a revisão do texto dos termos comerciais do
   distribuidor.
2. **Arrependimento de 7 dias na compra de insumo** — a desistência pelo site
   (`ReturnRequest::WITHDRAWAL_WINDOW_DAYS`) vale para todo pedido, mas o
   artesão que compra insumo para produzir pode não ser consumidor para o CDC,
   e a devolução de até 30 kg custa muito mais frete que a de uma peça. Vai ao
   advogado na mesma consulta da nota fiscal. **Até a resposta, a regra é a
   mesma do ateliê.**
3. **Segunda conta do Mercado Pago para o mesmo CPF** — confirmar com o
   provedor se a mesma pessoa pode ter uma conta para o ateliê e outra para a
   distribuidora (ou se precisa de CNPJ). Não muda a decisão de CPF por tipo;
   muda o que o cadastro do distribuidor orienta.
4. **Mensalidade e comissão do distribuidor** — análise de 2026-11-07, sem
   decisão e sem mudança no código. **Até a revisão, o distribuidor paga só
   comissão, sem mensalidade.**
   * **Por que não cobrar mensalidade agora:**
     * a demanda de insumos vem dos artesãos da própria EloShop e as vendas
       ainda não abriram. Cobrar todo mês antes de haver comprador afasta os
       primeiros distribuidores, enquanto a comissão só cobra quando ele vende;
     * a comissão sai no split do Mercado Pago. Mensalidade é cobrança de
       serviço: pede nota fiscal da EloShop e uma relação comercial mais
       formal, o que esbarra na formalização ainda pendente com o advogado e o
       contador (a EloShop não tem CNPJ);
     * não há cobrança recorrente no sistema. Seria um projeto à parte:
       assinatura no Mercado Pago, fora do split; inadimplência (aviso,
       carência, suspensão e reativação); histórico de cobranças; termos; e o
       destino dos pedidos em andamento de quem deixou de pagar. É maior que a
       Fase 26 inteira;
     * o rascunho dos termos do distribuidor e a página "Como funciona" dizem
       "Não há mensalidade, no momento". O "no momento" deixa a porta aberta
       sem prometer nada.
   * **Quando reavaliar:** 3 meses depois da abertura das vendas de insumos,
     com quanto cada distribuidor vende por mês e quanto paga de comissão. Se
     houver volume, o formato recomendado é um **plano opcional** ("R$ X por
     mês e comissão menor", escolhido pelo distribuidor quando compensa), no
     lugar de uma mensalidade obrigatória.
   * **Antes de ligar o cadastro em produção:** confirmar com dois ou três
     distribuidores se 15% sobre insumo é viável. A margem de atacado é menor
     que a de peça artesanal, e essa taxa (decidida igual à do ateliê) pode
     afastar fornecedores. Se precisar mudar, a hora é agora, com os termos do
     distribuidor ainda em rascunho com o advogado.

## Consequências

* `Seller` ganha `kind`; regras específicas (taxa, vitrine, campos do painel)
  passam a perguntar o tipo em um lugar só, nunca com `if distributor?`
  espalhado.
* `Product` ganha unidade de venda, quantidade mínima e faixas de preço. A
  disponibilidade continua com fonte única em `Product#available_for_purchase?`;
  insumo é `standard` com estoque (sob encomenda e peça única não se aplicam).
* O carrinho e o checkout passam a validar mínimo e faixa no servidor.
* Frete de insumo depende de cotação externa real — por isso a dependência da
  SuperFrete estável. Sem cotação, vale o frete fixo do distribuidor; a tabela
  interna nunca se aplica a ele.
* `sellers.cpf_hash` passa a ser único por `(cpf_hash, kind)`, e o cupom ganha
  escopo por tipo de vendedor.

## Dependências

* Acompanhamento dos primeiros ateliês depois da abertura das vendas.
* SuperFrete funcionando de forma estável em produção (ADR 005).
