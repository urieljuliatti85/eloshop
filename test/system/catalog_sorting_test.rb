require "application_system_test_case"

# Os request specs cobrem o servidor (ordenação, lista fechada de valores,
# paginação). O que só o navegador prova é o auto-submit: os seletores
# "Mostrar" e "Ordenar por" não têm botão visível, então mudar a opção precisa
# submeter o formulário sozinho — se o Stimulus não carregar ou o controller
# não estiver registrado, a vitrine simplesmente ignora a escolha do cliente,
# em silêncio e sem erro.
class CatalogSortingTest < ApplicationSystemTestCase
  test "ordenar por preço reordena a vitrine sem clicar em nenhum botão" do
    visit products_path

    select "Menor preço", from: "Ordenar por"

    # Esperar pela URL, e não por um texto que já estava na página antes da
    # troca: só a navegação prova que o auto-submit aconteceu. Asserção que já
    # era verdade antes da ação não espera nada e devolve a página velha.
    assert_current_path(/sort=menor-preco/)
    assert_ordenado_por_preco_crescente

    select "Maior preço", from: "Ordenar por"

    assert_current_path(/sort=maior-preco/)
    assert_ordenado_por_preco_decrescente
  end

  test "mudar a quantidade exibida recarrega a vitrine" do
    visit products_path

    select "8", from: "Mostrar"

    assert_current_path(/per_page=8/)

    # A escolha precisa sobreviver ao recarregamento: se o formulário submeter
    # mas a view não marcar a opção, o seletor volta ao padrão e o cliente não
    # entende por quê.
    assert_selector "select[name='per_page'] option[selected]", text: "8", visible: :all
  end

  private

  def precos_na_ordem_exibida
    all("[data-product-price]").map { |node| node.text.gsub(/\D/, "").to_i }
  end

  def assert_ordenado_por_preco_crescente
    precos = precos_na_ordem_exibida
    assert precos.size >= 2, "a vitrine precisa de ao menos dois produtos para provar ordenação"
    assert_equal precos.sort, precos, "esperava preços em ordem crescente, veio #{precos.inspect}"
  end

  def assert_ordenado_por_preco_decrescente
    precos = precos_na_ordem_exibida
    assert precos.size >= 2, "a vitrine precisa de ao menos dois produtos para provar ordenação"
    assert_equal precos.sort.reverse, precos, "esperava preços em ordem decrescente, veio #{precos.inspect}"
  end
end
