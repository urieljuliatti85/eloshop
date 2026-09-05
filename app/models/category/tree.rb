# A árvore de categorias inteira em uma leitura, respondida em memória.
#
# As perguntas de hierarquia do `Category` (breadcrumb, descendentes) sobem
# ou descem a árvore um nível por vez, e cada nível é uma ida ao banco. Isso
# é barato para uma categoria só — a PDP resolve com `includes(category:
# :parent)` — e caro para uma página que renderiza todas: o filtro do
# catálogo mostra o breadcrumb de cada categoria, e o custo era uma query
# por nível, por categoria.
#
# Carrega sempre a árvore completa de propósito: um `breadcrumb_name` sobre
# um recorte da árvore devolveria um caminho truncado, sem erro nenhum.
class Category::Tree
  def self.load(order: :name)
    new(Category.order(order).to_a)
  end

  attr_reader :categories

  def initialize(categories)
    @categories = categories
    @children = categories.group_by(&:parent_id)
    @by_id = categories.index_by(&:id)
  end

  # Categorias de topo, na ordem em que a árvore foi carregada.
  def roots
    Array(@children[nil])
  end

  # Só as categorias que a loja pode mostrar: exclui as desabilitadas e as
  # que estão sob uma desabilitada.
  def visible
    @visible ||= categories.reject { |c| hidden_ids.include?(c.id) }
  end

  # Categorias de topo visíveis — a home e o filtro do catálogo partem daqui.
  def visible_roots
    roots & visible
  end

  # Ids das categorias desabilitadas e de toda a subárvore abaixo delas.
  # Uma passada só: como `categories` vem ordenada por nome, e não por
  # profundidade, a herança do pai é resolvida descendo a partir de cada
  # raiz inativa.
  def hidden_ids
    @hidden_ids ||= begin
      hidden = []
      queue = categories.reject(&:active?).map(&:id)

      until queue.empty?
        id = queue.shift
        next if hidden.include?(id)

        hidden << id
        Array(@children[id]).each { |child| queue << child.id }
      end

      hidden
    end
  end

  # A própria categoria mais toda a subárvore abaixo dela — usado para
  # filtrar produtos: uma categoria pai deve mostrar também os produtos das
  # subcategorias, senão uma categoria só com filhas apareceria vazia.
  def self_and_descendant_ids(category)
    ids = [ category.id ]
    queue = [ category.id ]

    until queue.empty?
      Array(@children[queue.shift]).each do |child|
        ids << child.id
        queue << child.id
      end
    end

    ids
  end

  # A categoria pai, ou nil quando é de topo. Responde da árvore já carregada,
  # evitando o `belongs_to` ir ao banco linha a linha.
  def parent(category)
    @by_id[category.parent_id]
  end

  # Nome completo com a hierarquia, ex.: "Casa > Decoração".
  def breadcrumb_name(category)
    names = [ category.name ]
    current = category

    while (current = @by_id[current.parent_id])
      names.unshift(current.name)
    end

    names.join(" > ")
  end
end
