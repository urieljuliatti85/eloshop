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

### Criação desligada no painel do vendedor (2026-11-02)

Por decisão de produto, o artesão não cria novas variantes nem campos de personalização: `Product::SELLER_VARIANTS_AND_PERSONALIZATION_ENABLED = false` esconde os botões e as seções vazias em `/painel/produtos/:id`, e `SellerPortal::ProductVariantsController` / `SellerPortal::PersonalizationOptionsController` recusam `new`/`create` no servidor. A implementação continua inteira: o que já foi cadastrado segue valendo na loja, no carrinho e no checkout, e por isso continua visível para o artesão editar ou remover — esconder também isso deixaria estoque de variante e campo obrigatório sem gestão. O admin não é afetado. Para religar, basta trocar a constante.

## Imagens

Usar Active Storage. O produto tem uma imagem principal (`main_image`) claramente definida como capa — não depende da ordem acidental dos anexos. **As fotos são reduzidas no envio** (`Images::Optimizer`, chamado por `ProductGalleryUploads` nos cadastros do vendedor e do admin): no máximo 2.400 px no lado maior, qualidade 85, orientação EXIF aplicada e metadados removidos (inclusive localização). PNG sem transparência vira JPEG; PNG com transparência segue PNG. Antes o site guardava o original inteiro, e fotos de celular (2 a 5 MB) enchiam o volume de 500 MB da Railway e eram recusadas acima de 5 MB. Agora se aceita até 20 MB de arquivo bruto; o limite de 5 MB do `Product` vale para o arquivo já otimizado. Se a imagem não abrir, ou a versão reduzida não ficar menor, o original segue e as validações do produto decidem. O volume de imagens fica em `RAILS_STORAGE_PATH`; ver `docs/architecture.md` sobre o limite do plano.

Galeria de fotos adicionais `(Fase 15)`: `has_many_attached :images`, até 2 fotos por produto (`Product::IMAGES_MAX_COUNT`; produtos antigos com mais fotos continuam como estão, só não aceitam acréscimo), validadas (tipo, tamanho) antes de anexar. `main_image` sempre aparece primeiro; a ordem do restante segue a ordem de upload.

### Ampliação da foto

Na PDP, a foto principal é um botão ("Ampliar foto") que abre a foto à vista num `<dialog>` nativo (`gallery_controller.js`): inteira e sem o corte da moldura (`object-cover`, 4:3 no celular), com pinça no celular (`touch-pinch-zoom`). Fecha por Esc, pelo botão "Fechar", clicando no fundo e ao sair da página (`turbo:before-cache`, para o "voltar" não reabrir), e devolve o foco a quem abriu. **A ampliação usa a mesma versão de 1200 px da foto principal**, no mesmo endereço (rota do Active Storage, que não expira): vem do cache do navegador, não gera variante nova nem ocupa mais o volume. Não usar o arquivo original: fotos enviadas antes do optimizer (2026-10-01) podem ter até 5 MB e manter metadados, e as variantes do libvips só removem metadados com `strip` (testado em 2026-11-02, ver a revisão no roteiro). Uma versão maior, se faltar detalhe no desktop, deve ter `strip` e ser carregada só ao abrir.

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

### Filtro de categorias e autocomplete da vitrine

`/produtos` abre com uma **busca** e, logo abaixo, a **faixa de categorias**. O dropdown no começo da busca escolhe a categoria (ela e as filhas, como o filtro do catálogo) em que a busca vale; "Todas as categorias" é o padrão. Sem JavaScript é um formulário GET comum.

* **Faixa de categorias:** um único botão, **"Ver todos"**, que abre o menu com todas as categorias. Antes eram "Todos" e uma pílula por categoria de topo (com dropdown nas que têm filhas), que ocupavam duas linhas com a árvore completa e foram removidas. A página abre sem categoria, mostrando todos os produtos; "Todos os produtos", primeiro item do menu, volta a essa listagem.
* **Menu "Ver todos":** `products/_category_browser`. Primeiro "Todos os produtos" e depois todas as categorias de topo em uma coluna. No desktop, escolher uma abre as filhas ao lado, à direita (submenu lateral); o mouse e as setas trocam a categoria em foco, e o painel já abre mostrando as filhas da categoria atual (ou da primeira). No celular não há largura para uma segunda coluna: tocar numa categoria expande as filhas por baixo dela, e um segundo toque recolhe. Abrir/fechar o painel é do `account-menu`; a escolha e o teclado (↑ ↓ → ←, Esc) são do `category_flyout_controller.js`.
* **Hashtags:** a faixa de tags (`#feito-a-mao`…) saiu da vitrine. O filtro `?tag=` segue funcionando no servidor (links já compartilhados), só não há mais controle visível para ele.
* **Autocomplete de produtos:** `GET /produtos/sugestoes?q=&category=` devolve JSON com até 8 produtos (`name`, `category`, `url`), a partir de 2 caracteres, com a mesma busca (`Product.matching_query`) e a mesma visibilidade (`publicly_visible`, categoria desabilitada fora) da listagem. Categoria desconhecida ou desabilitada devolve lista vazia. A rota é pública e limitada a 60 requisições por minuto por IP (`rate_limit`), porque dispara uma consulta por pausa de digitação. O `product_autocomplete_controller.js` espera 200 ms, cancela a requisição anterior (resposta velha não sobrescreve a nova), preenche o DOM por `textContent` (nunca HTML) e segue o padrão ARIA de combobox (setas, Enter, Esc). Enter sem escolher uma sugestão roda a busca normal na categoria escolhida.

A partir da Fase 11, a busca deve considerar nome, descrição, categoria, tags, materiais e técnicas, começando com os recursos de busca do próprio PostgreSQL. Não introduzir um mecanismo de busca externo (ex.: Elasticsearch) antes de existir necessidade real e medida.

Filtros (categoria, preço, material, técnica, cor, disponibilidade, personalização, sob encomenda) também são pós-MVP e devem ser suportados por índices apropriados quando implementados.

## Categorias e hierarquia

Categorias são uma árvore (`parent`/`children`). As perguntas de hierarquia existem em duas formas, de propósito:

* `Category#breadcrumb_name` e `Category#self_and_descendant_ids` sobem ou descem a árvore um nível por vez, e cada nível é uma ida ao banco. Servem para **uma** categoria — a PDP e o admin, onde `includes(category: :parent)` já resolve o custo.
* `Category::Tree` carrega a árvore inteira em uma leitura e responde as mesmas perguntas em memória. Serve para páginas que renderizam **todas** as categorias — o filtro do catálogo, que mostra o breadcrumb de cada uma, e a home. Ver a Fase 17 do `ROADMAP.md` para a medição que motivou a separação.

`Category::Tree` carrega sempre a árvore completa de propósito: um breadcrumb calculado sobre um recorte devolveria um caminho truncado, sem erro nenhum.

### Sugestão de categoria pelo ateliê (2026-11-04)

No cadastro do produto, abaixo da categoria, o ateliê pode sugerir uma categoria que não achou. O admin vê as sugestões em **Categorias → Categorias sugeridas** (`/admin/categorias-sugeridas`), com o nome e os ateliês que pediram (nome e e-mail). Ele aceita escolhendo a categoria-mãe, e pode corrigir o nome, ou recusa. As duas decisões avisam por e-mail todos os ateliês que sugeriram.

* **Uma sugestão por nome.** `CategorySuggestion#normalized_key` é `name.squish.parameterize`, a mesma regra do slug de `Category` (ignora caixa, acento e espaço). Um índice único **parcial** sobre as pendentes garante isso no banco, inclusive com dois ateliês sugerindo ao mesmo tempo (`create_or_find_by!`). Quem sugeriu fica em `CategorySuggestionRequest`, único por sugestão e ateliê. A chave tem até 80 caracteres (o `parameterize` pode crescer o nome: "Æ" vira "ae"); acima disso, o nome é recusado com mensagem, não com erro do banco. Recusada, a chave fica livre: o mesmo nome pode voltar como sugestão nova (decisão de 2026-11-04).
* **Nome que já existe é recusado na hora**, com o caminho da categoria. A comparação usa o slug **e** o nome de todas as categorias, inclusive as inativas (elas continuam no seletor do ateliê) e as renomeadas (renomear mantém o slug antigo).
* **Aceitar** trava a sugestão, cria a categoria pelo próprio model (o `after_commit` invalida o cache de `Category::Tree`, e ela aparece no seletor na hora) e encerra a sugestão, tudo numa transação. O slug é único na árvore inteira: um nome que já existe sob outra mãe é recusado com uma mensagem, e a sugestão continua pendente. Decidir duas vezes não faz nada. A mãe precisa estar na loja: o seletor só oferece categorias visíveis, e o model recusa uma mãe desabilitada ou sob uma desabilitada, porque a categoria nova nasceria escondida e o e-mail diria ao ateliê que ela está disponível.
* **O produto não muda sozinho** (decisão de 2026-11-04): o e-mail de aceite convida o ateliê a escolher a categoria nova. Enquanto isso, o produto pode ficar em rascunho sem categoria, que só é exigida para publicar.
* **O envio não depende do produto.** O campo e o botão ficam dentro do formulário do produto, mas pertencem a um formulário irmão (`form="category-suggestion-form"`): não levam os campos nem as fotos do produto e não passam pela validação dele. A resposta é um Turbo Stream que troca o bloco pela mensagem. Limite de 5 sugestões por hora por ateliê.
* **E-mail por ateliê.** Depois do commit, `NotifyCategorySuggestionDecisionJob` é enfileirado uma vez para cada ateliê, e `notified_at` impede o segundo envio. Se o processo morrer entre o commit e o enfileiramento, a sugestão decidida fica com pedidos sem `notified_at`. Para reenviar, via `railway ssh`:

  ```bash
  bin/rails runner 'CategorySuggestionRequest.joins(:category_suggestion).where(notified_at: nil).where.not(category_suggestions: { status: "pending" }).find_each { |r| NotifyCategorySuggestionDecisionJob.perform_later(r) }'
  ```

## Relação com estoque

A disponibilidade de compra de um produto (pode ou não ser adicionado ao carrinho/comprado) é derivada do estado de estoque, cuja fonte de verdade e regras estão descritas em `docs/inventory.md`. O catálogo não deve duplicar essa lógica — apenas consultar a disponibilidade centralizada.
