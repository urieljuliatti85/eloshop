# Catalog

Este documento descreve as regras do catálogo de produtos. Para as entidades de domínio, ver `docs/domain.md`. Para o escopo de cada fase, ver `ROADMAP.md`.

## Ciclo de vida do produto

```text
draft
  ↓
active
  ↓
sold_out
  ↓
discontinued
```

* `draft`: produto em cadastro, não visível na loja.
* `active`: produto publicado e disponível para compra (sujeito à disponibilidade de estoque — ver `docs/inventory.md`).
* `sold_out`: produto publicado, mas sem estoque disponível no momento.
* `discontinued`: produto não será mais vendido.

Produtos em `draft` ou `discontinued` não devem aparecer na listagem pública nem ser acessíveis diretamente pela URL (ver `docs/security.md`, "Autorização" — o mesmo princípio de não confiar apenas em "esconder" se aplica aqui: a checagem de visibilidade deve acontecer no servidor a cada requisição, não só na listagem).

## Atributos do produto

### Escopo do MVP

No MVP (Fases 0–7), o produto possui apenas os atributos necessários para o fluxo mínimo de venda:

* nome
* slug
* descrição
* preço (`price_cents` + `currency` — nunca `Float`, ver `docs/domain.md` e `CLAUDE.md`)
* SKU
* quantidade em estoque
* status (ciclo de vida acima)
* imagem principal

### Escopo pós-MVP

Os atributos abaixo fazem parte do domínio de artesanato descrito no `CLAUDE.md`, mas não devem ser implementados antes de existir uma justificativa de negócio concreta e a fase correspondente do roadmap ser iniciada:

* descrição curta
* preço promocional
* categoria, tags, materiais, técnicas (Fase 11)
* dimensões, peso
* cores
* imagens adicionais, vídeos
* variações (Fase 9)
* prazo de produção (relevante apenas para produtos sob encomenda — Fase 8)
* informações de personalização (Fase 10)
* informações sobre o processo artesanal
* artista/artesão, coleção, origem, cuidados, história da peça, informações de sustentabilidade

Cada atributo novo deve ter justificativa de negócio antes de ser adicionado — não adicionar campos apenas porque são possíveis.

## Imagens

Usar Active Storage. O produto deve ter uma imagem principal claramente definida (não depender da ordem acidental dos anexos).

Galeria de imagens adicionais, imagens de detalhe/escala/processo/embalagem e otimizações de performance (variantes de imagem, thumbnails, lazy loading, CDN) são pós-MVP e devem ser tratadas quando o volume de catálogo justificar.

## URLs e SEO

Produtos devem ser acessíveis por slug amigável (`/produtos/caneca-artesanal-azul`), não por ID cru. Isso vale desde o MVP, pois faz parte da estrutura básica de roteamento, não de uma funcionalidade avançada de SEO.

Meta tags, Open Graph, dados estruturados e sitemap são pós-MVP (Fase 16).

## Busca e filtros

No MVP não há busca nem filtros — apenas listagem simples de produtos ativos.

A partir da Fase 11, a busca deve considerar nome, descrição, categoria, tags, materiais e técnicas, começando com os recursos de busca do próprio PostgreSQL. Não introduzir um mecanismo de busca externo (ex.: Elasticsearch) antes de existir necessidade real e medida.

Filtros (categoria, preço, material, técnica, cor, disponibilidade, personalização, sob encomenda) também são pós-MVP e devem ser suportados por índices apropriados quando implementados.

## Relação com estoque

A disponibilidade de compra de um produto (pode ou não ser adicionado ao carrinho/comprado) é derivada do estado de estoque, cuja fonte de verdade e regras estão descritas em `docs/inventory.md`. O catálogo não deve duplicar essa lógica — apenas consultar a disponibilidade centralizada.
