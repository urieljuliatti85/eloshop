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
* tags, materiais, técnicas (Fase 11)
* dimensões, peso
* cores
* imagens adicionais, vídeos
* informações sobre o processo artesanal
* artista/artesão, coleção, origem, cuidados, história da peça, informações de sustentabilidade

Cada atributo novo deve ter justificativa de negócio antes de ser adicionado — não adicionar campos apenas porque são possíveis.

## Variações `(Fase 9)`

Produtos `standard` podem ter variações comerciais reais (tamanho, cor, material), cada uma com SKU, preço e estoque próprios — ver `ProductVariant` em `docs/domain.md` e `docs/decisions/001-product-variants.md`. Peça única e sob encomenda não suportam variação nesta fase. Quando o produto tem variação, o preço exibido no catálogo é "a partir de" o menor preço entre as variações ativas — o `price_cents` do produto em si não representa nenhuma opção comprável.

## Personalização `(Fase 10)`

Qualquer produto pode ter campos de personalização em texto livre (ex.: nome gravado, mensagem) — ver `PersonalizationOption` em `docs/domain.md`. Diferente de variação, não muda SKU, estoque ou preço, e não é restrita a `availability_type: standard` nem é exclusiva de produto sem variação — as duas podem coexistir no mesmo produto.

## Imagens

Usar Active Storage. O produto tem uma imagem principal (`main_image`) claramente definida como capa — não depende da ordem acidental dos anexos.

Galeria de fotos adicionais `(Fase 15)`: `has_many_attached :images`, até 8 fotos por produto, validadas (tipo, tamanho) antes de anexar. `main_image` sempre aparece primeiro; a ordem do restante segue a ordem de upload.

Imagens de detalhe/escala/processo/embalagem como categorias distintas de foto, e otimizações de performance (variantes de imagem, thumbnails, lazy loading, CDN) continuam pós-MVP e devem ser tratadas quando o volume de catálogo justificar.

## URLs e SEO

A raiz (`/`) é a home (`HomeController#show`): apresentação da loja e uma vitrine de categorias de topo (cada card leva ao catálogo já filtrado), sem listagem de produtos. A categoria não tem imagem própria — a capa do card é a foto do produto ativo mais recente da categoria ou de suas subcategorias, uma query com `LIMIT 1` por categoria de topo; enquanto não houver produto com foto, o card fica com o fundo areia. A vitrine vive em `/produtos` (`ProductsController#index`). Desde a Fase 22, a URL identifica o vendedor e o produto (`/artesaos/:seller_slug/produtos/:slug`), permitindo slugs repetidos entre artesãos sem usar ID cru. A URL legada `/produtos/:slug` redireciona permanentemente quando o slug identifica um único produto público; slugs ambíguos retornam 404.

Meta tags, Open Graph, dados estruturados e sitemap foram implementados na Fase 16: `SeoHelper` centraliza `page_title`/`page_description`/`canonical_url` (com fallback genérico do site quando a página não define nada) e `product_structured_data` gera o JSON-LD `schema.org/Product` (nome, imagem, SKU, `offers` com preço/disponibilidade, `aggregateRating` quando há reviews aprovadas). A PDP e o catálogo (incluindo filtro por categoria e busca) definem título/descrição/canonical próprios via `content_for`. `/sitemap.xml` é gerado dinamicamente (sem gem) com produtos ativos, categorias e páginas estáticas; `robots.txt` referencia o sitemap e desautoriza áreas não indexáveis (admin, carrinho, checkout, sessão). Não existe uma coluna dedicada de meta description — ela é derivada de `description` truncada, para não adicionar campo sem necessidade de negócio clara (CLAUDE.md §5).

## Busca e filtros

No MVP não há busca nem filtros — apenas listagem simples de produtos ativos.

A categoria hierárquica foi introduzida na Fase 11 como atributo opcional. O catálogo aceita `category` com o slug da categoria e inclui produtos de suas subcategorias; categorias desconhecidas retornam 404. Tags, materiais e técnicas são entidades reutilizáveis associadas ao produto por tabelas de junção e podem ser administradas pelos campos separados por vírgula no cadastro do produto.

Uma categoria pode ser **desabilitada** (`categories.active = false`) pelo admin. O efeito é derivado e reversível: os produtos dela e de toda a subárvore abaixo somem do catálogo, da busca, da home, do sitemap, da API e da URL direta, e deixam de ser compráveis — mas o `status` de cada produto não é tocado, então reabilitar a categoria devolve tudo ao ar. Decisão de catálogo é da plataforma; o `status` do produto é do vendedor (§34, §69). A regra tem duas portas, as mesmas de sempre: `Product.publicly_visible` (listagens) e `Product#available_for_purchase?` (compra, via carrinho e checkout) — nunca verificar `category.active` espalhado. Produto sem categoria nunca é escondido por isso: `category_id` é opcional e ausência não é desabilitação. `Category::Tree#hidden_ids` resolve a subárvore em memória, sobre a árvore que o catálogo já carregava — medido: 12 queries em `/produtos` antes e depois.

O catálogo também aceita `q` (nome ou descrição), `tag`, `material`, `technique`, `availability`, `min_price`, `max_price` e `personalizable=1`. Todos os filtros são combináveis e os valores são recalculados no servidor; `q` usa `ILIKE` do PostgreSQL.

A vitrine também aceita `sort` e `per_page`, expostos na barra "Ordenar por" / "Mostrar". Os dois são listas fechadas no `ProductsController` (`SORT_OPTIONS` e `PER_PAGE_OPTIONS`), porque viram `ORDER BY` e `LIMIT`: valor fora da lista cai no padrão (`recentes`, 12 por página) em vez de chegar ao SQL. A paginação preserva os demais parâmetros da query string; trocar ordenação ou tamanho de página volta para a primeira página.

A partir da Fase 11, a busca deve considerar nome, descrição, categoria, tags, materiais e técnicas, começando com os recursos de busca do próprio PostgreSQL. Não introduzir um mecanismo de busca externo (ex.: Elasticsearch) antes de existir necessidade real e medida.

Filtros (categoria, preço, material, técnica, cor, disponibilidade, personalização, sob encomenda) também são pós-MVP e devem ser suportados por índices apropriados quando implementados.

## Categorias e hierarquia

Categorias são uma árvore (`parent`/`children`). As perguntas de hierarquia existem em duas formas, de propósito:

* `Category#breadcrumb_name` e `Category#self_and_descendant_ids` sobem ou descem a árvore um nível por vez, e cada nível é uma ida ao banco. Servem para **uma** categoria — a PDP e o admin, onde `includes(category: :parent)` já resolve o custo.
* `Category::Tree` carrega a árvore inteira em uma leitura e responde as mesmas perguntas em memória. Serve para páginas que renderizam **todas** as categorias — o filtro do catálogo, que mostra o breadcrumb de cada uma, e a home. Ver a Fase 17 do `ROADMAP.md` para a medição que motivou a separação.

`Category::Tree` carrega sempre a árvore completa de propósito: um breadcrumb calculado sobre um recorte devolveria um caminho truncado, sem erro nenhum.

## Relação com estoque

A disponibilidade de compra de um produto (pode ou não ser adicionado ao carrinho/comprado) é derivada do estado de estoque, cuja fonte de verdade e regras estão descritas em `docs/inventory.md`. O catálogo não deve duplicar essa lógica — apenas consultar a disponibilidade centralizada.
