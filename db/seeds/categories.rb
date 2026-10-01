# Categorias iniciais do marketplace de artesanato, acima das de `db/seeds.rb`
# (Casa, Moda, Presentes).
#
# O entrypoint roda `db:seed` a cada boot em produção, então este arquivo é
# estritamente ADITIVO: só cria o que não existe e nunca altera, reativa,
# move ou apaga uma categoria já presente (o admin pode renomear, desativar
# ou reorganizar à vontade). Se um nome já existe sob o mesmo pai, ou o slug
# já está em uso em outro lugar da árvore, a categoria é pulada. Falha aqui
# não pode interromper o resto do seed.
module CategorySeed
  # Raiz => subcategorias. Escolha de catálogo, feita com o Uriel em
  # 2026-10-01: o que um artesão de feira costuma vender. Categoria vazia vira
  # página vazia na vitrine, por isso a lista é curta.
  def self.tree
    {
      "Casa" => [ "Têxteis para casa", "Iluminação" ],
      "Moda" => [ "Roupas", "Bolsas e carteiras", "Joias e bijuterias" ],
      "Presentes" => [ "Datas especiais" ],
      "Infantil" => [],
      "Papelaria" => []
    }
  end

  def self.call
    tree.each do |root_name, children|
      root = ensure_category(root_name, parent: nil)
      next unless root

      children.each { |name| ensure_category(name, parent: root) }
    end
  end

  def self.ensure_category(name, parent:)
    existing = Category.find_by(name: name, parent: parent)
    return existing if existing

    if Category.exists?(slug: name.parameterize)
      puts "Categoria '#{name}' ignorada: o slug '#{name.parameterize}' já está em uso em outro lugar da árvore."
      return nil
    end

    Category.create!(name: name, parent: parent)
  rescue ActiveRecord::ActiveRecordError => e
    puts "Categoria '#{name}' não criada: #{e.message}"
    nil
  end
end

CategorySeed.call
