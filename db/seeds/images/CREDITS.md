# Créditos das imagens de seed

Fotos de catálogo obtidas via [Openverse](https://openverse.org), todas com
licença que permite uso comercial. **CC BY e CC BY-SA exigem atribuição** — se
estas imagens forem exibidas publicamente, o crédito abaixo precisa aparecer em
algum lugar acessível do site.

As imagens foram redimensionadas para 1200px e recomprimidas em JPEG. Nenhuma
outra alteração foi feita.

| SKU | Título | Autor | Licença | Origem |
| --- | --- | --- | --- | --- |
| `CESTO-VIME-001` | Savat 4 | AIDEPCUL | CC BY 4.0 | [link](https://commons.wikimedia.org/w/index.php?curid=196845470) |
| `CAMISETA-001` | Stack of folded t-shirts | (não informado) | CC0 1.0 | [link](https://www.rawpixel.com/image/11515802/stack-folded-t-shirts) |
| `ALMOFADA-BORDADO-001` | handmade Om cushion | cernaovec | CC BY-SA 2.0 | [link](https://www.flickr.com/photos/69599449@N05/16361200206) |
| `COLAR-MACRAME-001` | Natural wood pendant necklace with macrame, handmade | john bonham2 | CC BY-SA 2.0 | [link](https://www.flickr.com/photos/95205391@N05/27851846113) |
| `JOGO-CROCHE-001` | Crochet Doily | noricum | CC BY-SA 2.0 | [link](https://www.flickr.com/photos/43437767@N00/1303641701) |
| `CANECA-001` | Celtic Clays Mug | IrishFireside | CC BY 2.0 | [link](https://www.flickr.com/photos/43762537@N00/2535213015) |

## Importante

Estas **não são fotos das peças à venda** — são imagens de artesanato de outras
pessoas, usadas como catálogo de demonstração. Para uma loja em operação real,
cada produto precisa da foto da peça que o cliente vai receber, ainda mais em
artesanato, onde cada peça é única (ver `docs/domain.md`). Substituir antes de
vender de verdade.

## Como adicionar ou trocar a foto de um produto

Coloque o arquivo como `db/seeds/images/<SKU>.jpg` e rode `bin/rails db:seed`.
O seed usa a foto quando ela existe e cai no gradiente quando não existe.

Ele **não** sobrescreve imagem enviada pelo admin: só substitui o placeholder
que ele mesmo gerou (PNG com o nome `<slug>.png`). Para trocar uma foto que já
está publicada, remova a imagem pelo admin antes.

Produtos ainda sem foto real, servidos por gradiente:

- `BOWL-ENCOMENDA-001`
- `LUMINARIA-CERAMICA-001`
- `TABUA-MADEIRA-001`
- `VASO-AZUL-001`
