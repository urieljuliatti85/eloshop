# ADR 005 — Provedor de frete

## Status

Accepted — provedor definido em 2026-09-06: **Melhor Envio**. Nenhuma
integração foi escrita ainda; as decisões de etiqueta e frete grátis seguem
pendentes e travam apenas as Etapas 2 e 3.

Opções revisadas em 2026-09-06 com a documentação pública dos provedores
([Melhor Envio](https://docs.melhorenvio.com.br/reference/introducao-api-melhor-envio)).
Preço e política desses serviços mudam: confirmar antes de assinar.

## Context

`docs/shipping.md` traz um `TODO — DECISION REQUIRED` sobre qual transportadora ou serviço de cálculo integrar. O frete hoje é calculado por `Shipping::Calculator`, uma tabela interna: R$ 15,00 de base mais R$ 5,00 por quilo, com prazo de 5 ou 8 dias conforme a faixa de CEP. O valor não reflete custo real de envio.

O que já existe e não precisa ser construído:

* `Shipping::Calculator` é um objeto isolado com interface própria (`Result` com `carrier`, `service`, `shipping_cents`, `estimated_days`) — trocar o provedor não contamina o domínio.
* `Shipment` já tem `carrier`, `service`, `tracking_code`, `shipped_at` e `delivered_at`, e pertence ao `SellerOrder`, de modo que frete e fulfillment já estão isolados por vendedor.
* `Seller` tem endereço de origem desde 2026-09-06 (PR #53): sem CEP de origem nenhum cálculo real funciona.
* `Product` exige peso e dimensões para ser publicado desde 2026-09-06 (PR #54); o catálogo publicado tem 100% de cobertura.
* O projeto já tem infraestrutura de webhook idempotente (Mercado Pago) reaproveitável para status de entrega.

Ou seja: falta o provedor, não a fundação.

## Decision

**Melhor Envio.** A carteira pré-paga responde de saída a uma das decisões pendentes: como o cadastro aceita CPF, **cada artesão pode ter a própria conta**, no mesmo arranjo do Mercado Pago — a plataforma não precisa comprar etiqueta e descontar do repasse, o que manteria o split intocado.

Os três caminhos avaliados:

### A. Correios via API

Cobertura nacional real, inclusive onde transportadora privada não atende — relevante num marketplace com artesãos espalhados. A marca é reconhecida pelo cliente.

Exige contrato. A API é lenta e instável: sem cache e timeout curto, cada mudança de CEP no checkout pode travar a compra. Não resolve etiqueta nem rastreio, que seriam uma segunda integração.

### B. Agregador (Melhor Envio, SuperFrete)

Uma integração dá acesso a Correios, Jadlog, Loggi e outras, **com etiqueta e rastreio prontos**. Costuma sair mais barato que balcão dos Correios, porque negociam volume; a API tende a ser mais estável e melhor documentada.

Custa comissão por envio e cria dependência de um intermediário: se ele cair ou mudar preço, a plataforma absorve.

**Duas opções foram descartadas na pesquisa de 2026-09-06:**

* **Kangu** encerrou a intermediação de envios em fevereiro de 2025.
* **Frenet** é gateway, não agregador: conecta contratos que o lojista *já negociou* com transportadoras. Só serve se a plataforma tiver contrato próprio, o que não é o caso.

**SuperFrete** absorveu boa parte dos usuários do Kangu e afirma ter mais de 100 mil lojistas ativos. Não foi avaliada tecnicamente — vale comparar antes de fechar.

**Melhor Envio — o que a documentação confirma (2026-09-06):**

* **Integração gratuita**, sem taxa nem mensalidade; a receita vem do spread do frete.
* **Sandbox** com R$ 10.000 de saldo fictício para gerar etiquetas de teste, em conta separada da produção — mesmo arranjo já usado no Mercado Pago.
* **OAuth2 com refresh token** (access de 30 dias, refresh de 45). É exatamente o padrão que o projeto já implementou em `Marketplace::MercadoPagoOauth`, com tokens cifrados: o desenho é reaproveitável.
* **A cotação exige só CEP de origem, CEP de destino e os volumes** (dimensões em cm, peso em kg) — o que os PRs #53 e #54 acabaram de garantir.
* Endpoints documentados para as três etapas, **incluindo webhooks** de status.

**Pessoa física está confirmada (2026-09-06):** o cadastro aceita CPF ou CNPJ, inclusive MEI e Simples Nacional, sem mensalidade, contrato ou número mínimo de envios. Era a condição decisiva — a maioria dos artesãos não tem CNPJ. O pagamento das etiquetas sai de uma carteira digital pré-paga, sem prazo de validade do saldo ([fonte](https://melhorenvio.com.br/blog/sobre-nos/melhor-envio-como-funciona/)).

O **rate limit** da API segue não documentado publicamente. Não bloqueia a decisão, mas o cache da Etapa 1 deixa de ser só otimização.

### C. Tabela própria por região

O que existe hoje, evoluído. Sem dependência externa, previsível, e o vendedor sabe quanto vai receber. Custo de integração zero.

Não reflete custo real — ou a plataforma perde margem nos envios longos, ou cobra a mais nos curtos. Não resolve etiqueta nem rastreio: o artesão despacha por conta e informa o código à mão.

### Por que Melhor Envio

**B, agregador — Melhor Envio.** Três razões: o rastreio será necessário logo (clientes perguntam pelo pedido, e hoje não há resposta no sistema), e com Correios puro seria outra integração; a etiqueta importa num marketplace onde o artesão vende pouco e não tem contrato próprio; e o `Shipping::Calculator` já isolado torna barato trocar de agregador depois, enquanto sair de tabela própria para API custa mais.

A pesquisa reforçou a escolha: o OAuth2 do Melhor Envio é o mesmo padrão já implementado para o Mercado Pago, a cotação exige exatamente os dados que o catálogo passou a ter, e o cadastro por CPF cobre o artesão sem CNPJ — que é a maioria.

## Decisões de negócio pendentes

Independentes do provedor escolhido:

1. **Quem paga a etiqueta.** Com o cadastro por CPF confirmado, o caminho natural é **cada artesão com a própria conta**, conectada por OAuth como já acontece com o Mercado Pago: não mexe no split de comissão, e o saldo é dele. O custo é mais um passo no onboarding, e o artesão precisa manter saldo na carteira — se ela zerar, ele não emite etiqueta. A alternativa (plataforma compra e desconta do repasse) simplifica para o vendedor, mas mexe no split e faz a EloShop adiantar dinheiro. **Decisão ainda do negócio**, mas sem o impedimento que existiria se CPF não fosse aceito.
2. **Frete grátis existe?** A partir de qual valor, e por conta de quem — plataforma ou artesão. Afeta carrinho, cupom e comissão.
3. **Quem absorve a diferença** quando o frete real sai mais caro que o cobrado no checkout. Hoje a comissão exclui frete, então o vendedor absorveria por padrão.

## Consequences

Se B for aceito, a implementação se divide em três etapas, e só a primeira depende apenas da escolha do provedor:

**Etapa 1 — cotação real.** `Shipping::Providers::<Agregador>` implementa a interface existente. Duas decisões técnicas: quais opções mostrar (sugestão: a mais barata e a mais rápida, não todas) e **cache obrigatório** — origem + destino + peso se repetem muito, e sem cache cada mudança de CEP vira chamada externa. Timeout curto com **fallback para a tabela atual**: uma venda com frete estimado é melhor que uma venda perdida.

**Etapa 2 — etiqueta e rastreio.** Depende da decisão 1. O `tracking_code` já tem coluna.

**Etapa 3 — webhook de status.** Preenche `shipped_at` e `delivered_at`, reaproveitando o padrão idempotente do Mercado Pago.

O risco principal é o agregador virar dependência do checkout. A mitigação é manter a tabela atual como fallback — **não deletá-la**.
