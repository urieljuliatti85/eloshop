# ADR 007 — Distribuidores de insumos

## Status

Proposed — desenho registrado em 2026-10-31, **sem implementação**. As decisões
de escopo estão tomadas; a implementação só começa depois do acompanhamento dos
primeiros ateliês e com a SuperFrete funcionando de forma estável em produção
(ver "Dependências"); a meta de abertura da vertical é dezembro de 2026. Resta
pendente a declaração de nota fiscal (consulta jurídica).

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
desconectar volta para `pending` e despublica o catálogo.

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

## Decisões pendentes

1. **Declaração de emissão de nota fiscal** — obrigatória ou opcional; aguarda
   consulta jurídica, junto com a revisão do texto dos termos comerciais do
   distribuidor.

## Consequências

* `Seller` ganha `kind`; regras específicas (taxa, vitrine, campos do painel)
  passam a perguntar o tipo em um lugar só, nunca com `if distributor?`
  espalhado.
* `Product` ganha unidade de venda, quantidade mínima e faixas de preço. A
  disponibilidade continua com fonte única em `Product#available_for_purchase?`;
  insumo é `standard` com estoque (sob encomenda e peça única não se aplicam).
* O carrinho e o checkout passam a validar mínimo e faixa no servidor.
* Frete de insumo depende de cotação externa real — por isso a dependência da
  SuperFrete estável.

## Dependências

* Acompanhamento dos primeiros ateliês depois da abertura das vendas.
* SuperFrete funcionando de forma estável em produção (ADR 005).
