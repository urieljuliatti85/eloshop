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

Essa atualização é deliberadamente manual: não cria etiqueta, não afirma que
uma transportadora confirmou a entrega e não depende da integração bloqueada
com o Melhor Envio. Quando a Etapa 3 do ADR 005 existir, os webhooks do
provedor deverão convergir para as mesmas transições de `Shipment`.
