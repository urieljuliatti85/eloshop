# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

- **Artesãos (vendedores).** Pessoas que produzem e vendem as próprias peças, muitas vezes sem familiaridade com ferramentas digitais de venda. Usam o painel (`/painel`) com frequência pelo celular, na oficina, entre uma peça e outra. O trabalho do dia é saber se há pedido para preparar e enviar, cadastrar peças e acompanhar o que vão receber.
- **Compradores.** Clientes da vitrine que compram peças artesanais, com pagamento por PIX ou cartão.
- **Administradores da plataforma.** Aprovam artesãos, acompanham pedidos, comissão, reembolsos e alertas de fraude.

## Product Purpose

A EloShop é um marketplace de artesanato: cada artesão vende como entidade comercial independente, com catálogo, pedidos e recebimentos próprios. Sucesso, para o artesão, é sair do cadastro até a primeira venda sem se perder e, depois, operar o dia a dia (preparar, enviar e receber) sem dúvidas sobre o dinheiro.

## Positioning

Feito para peças artesanais, não para estoque genérico: peça única, sob encomenda (com prazo de produção registrado na compra), personalização e pequenas tiragens são conceitos de primeira classe. O recebimento é automático pelo split do Mercado Pago, sem repasse manual pela plataforma.

## Operating Context

- Para vender, o artesão completa cinco etapas, nesta ordem: endereço do ateliê, conexão da Conta Vendedor no Mercado Pago (OAuth), chave PIX cadastrada nessa conta, primeira peça e aprovação pela plataforma (`Seller#getting_started_steps`).
- A conexão com o Mercado Pago acontece fora da EloShop: o artesão sai para o site do Mercado Pago, autoriza e volta ao painel.
- A EloShop não consegue consultar se existe chave PIX: a etapa é concluída pela declaração do artesão.
- Conectar a conta não aprova o ateliê: o admin confirma a conta real e o KYC antes de aprovar.
- Há um tour guiado do painel que localiza seus passos pelos links do menu.

## Capabilities and Constraints

- Rails 8 com Hotwire (Turbo e Stimulus), importmap e Tailwind, sem build de JavaScript.
- CSP restritiva: nada de script inline sem nonce nem CDN externo; fontes externas exigiriam mudança na política.
- Dinheiro sempre em centavos. Comissão de 8% nos 3 primeiros meses após a aprovação e 15% depois, sobre produtos após descontos, sem frete.
- Um checkout aceita um único vendedor (split 1:1 do Mercado Pago).
- Os textos e a ordem dos fluxos de conexão do Mercado Pago, chave PIX e termos foram ajustados com cuidado; mudanças de texto nesses fluxos precisam de aprovação explícita.
- Interface em português do Brasil.

## Brand Commitments

- Nome EloShop, logo em `app/assets/images/logo.png`, cor de marca vermelho-laranja (#F33920) usada na vitrine.
- O painel do artesão pode ter identidade visual própria de ateliê (decisão de 2026-10-15); a vitrine mantém a identidade atual.

## Evidence on Hand

- Imagens existentes: `app/assets/images/atelie-banner.jpg`, `home-background.jpg`, `admin-sidebar-bg.jpg`, capturas do guia da chave PIX em `app/assets/images/pix_key/`.
- Não há depoimentos, números de vendas ou casos de artesãos publicáveis; nada disso deve ser inventado.

## Product Principles

1. O trabalho do dia vem antes da configuração: depois de pronto, o painel responde primeiro "tenho pedido para enviar e quanto vou receber?".
2. Um próximo passo por vez: o artesão nunca deve escolher entre vários avisos igualmente urgentes.
3. Dinheiro transparente: todo valor mostrado diz se já desconta a comissão, e o mesmo pedido mostra o mesmo número em qualquer tela.
4. O vocabulário é o do ateliê (peça, encomenda, produção), não o de sistema.
5. Vermelho como alerta só para o que realmente bloqueia a venda; a capa do caderno (Primeiros passos) usa o vermelho da marca, por escolha de 2026-10-15.

## Accessibility & Inclusion

Uso frequente em celular, com uma mão e em ambiente com luz forte: alvos de toque de 44px, contraste mínimo WCAG AA, estado comunicado por texto e não só por cor, e leitura simples para quem tem pouca familiaridade com ferramentas digitais.
