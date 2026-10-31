# Seed de PRODUÇÃO: categorias do marketplace de artesanato. É o único seed que
# a produção executa — `bin/docker-entrypoint` o carrega a cada boot, e
# `db/seeds.rb` (desenvolvimento) não o carrega nem roda em produção.
#
# O entrypoint roda `db:seed` a cada boot em produção, então este arquivo é
# estritamente ADITIVO: só cria o que não existe e nunca altera, reativa,
# move ou apaga uma categoria já presente (o admin pode renomear, desativar
# ou reorganizar à vontade). Se um nome já existe sob o mesmo pai, ou o slug
# já está em uso em outro lugar da árvore, a categoria é pulada. Falha aqui
# não pode interromper o resto do seed.
module CategorySeed
  # Raiz => subcategorias. Escolha de catálogo, feita com o Uriel: o primeiro
  # lote (2026-10-01) era curto porque categoria vazia vira página vazia na
  # vitrine; o segundo (2026-10-03) amplia a árvore de uma vez, a pedido dele,
  # para os ateliês já encontrarem onde publicar.
  #
  # O slug é único na árvore inteira, então nomes repetidos entre pais colidem
  # e a segunda seria pulada: "Acessórios" já é de Moda (daí "Acessórios para
  # pets"), e velas ficam só em Bem-estar. O teste confere que nenhum slug se
  # repete aqui. As subcategorias já existentes (Cozinha, Decoração, Acessórios)
  # vêm de `db/seeds.rb`.
  def self.tree
    {
      "Casa" => [
        "Têxteis para casa", "Iluminação", "Organização", "Jardim e plantas",
        "Banho e mesa posta", "Quadros e arte de parede", "Móveis e peças de madeira"
      ],
      "Moda" => [
        "Roupas", "Bolsas e carteiras", "Joias e bijuterias", "Calçados e sandálias",
        "Chapéus e lenços", "Moda praia", "Bordados e patches"
      ],
      "Presentes" => [
        "Datas especiais", "Aniversário", "Casamento", "Lembrancinhas", "Kits e cestas"
      ],
      "Infantil" => [
        "Brinquedos de madeira e pano", "Roupas de bebê", "Decoração de quarto infantil",
        "Enxoval de bebê"
      ],
      "Papelaria" => [
        "Cadernos e agendas", "Cartões e convites", "Adesivos e ilustrações",
        "Encadernação artesanal"
      ],
      "Bem-estar e cuidados" => [
        "Velas aromáticas", "Sabonetes artesanais", "Cosméticos naturais",
        "Aromaterapia e incensos"
      ],
      "Pets" => [ "Acessórios para pets", "Brinquedos para pets" ],
      "Festas e eventos" => [ "Decoração de festa", "Topos de bolo e lembranças personalizadas" ],
      "Arte e colecionáveis" => [ "Esculturas", "Pinturas e gravuras", "Miniaturas" ],
      "Materiais e aviamentos" => []
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
