# Imagens de seed do catálogo

Fotos usadas por `db/seeds.rb` como capa dos produtos de demonstração, obtidas
via [Openverse](https://openverse.org), todas com licença que permite uso
comercial. Foram redimensionadas para 1200px e recomprimidas em JPEG; nenhuma
outra alteração foi feita.

## Atribuição

**CC BY e CC BY-SA exigem crédito visível de quem publica a imagem.** Isso é
cumprido pela página `/creditos`, linkada no rodapé da loja.

A procedência de cada foto fica em **`credits.yml`**, neste mesmo diretório —
fonte única lida pela página. Este arquivo não repete os dados de propósito:
crédito divergente do que está publicado é descumprimento de licença.

## Como adicionar ou trocar a foto de um produto

1. Coloque o arquivo como `db/seeds/images/<SKU>.jpg`
2. Adicione a entrada correspondente em `credits.yml` (dispensável apenas se a
   foto for própria ou de domínio público)
3. Rode `bin/rails db:seed`

O seed usa a foto quando ela existe e cai no gradiente gerado em código quando
não existe. Ele **não** sobrescreve imagem enviada pelo admin: só substitui o
placeholder que ele mesmo gerou (PNG com o nome `<slug>.png`). Para trocar uma
foto já publicada, remova a imagem pelo admin antes.

## Produtos ainda sem foto real

Servidos por gradiente:

- `BOWL-ENCOMENDA-001`
- `LUMINARIA-CERAMICA-001`
- `TABUA-MADEIRA-001`
- `VASO-AZUL-001`

## Importante

Estas **não são fotos das peças à venda** — são imagens de artesanato de outras
pessoas, usadas como catálogo de demonstração. Para uma loja em operação real,
cada produto precisa da foto da peça que o cliente vai receber, ainda mais em
artesanato, onde cada peça é única (ver `docs/domain.md`). Substituir antes de
vender de verdade.
