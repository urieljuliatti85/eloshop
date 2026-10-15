---
name: EloShop — Caderno de Encomendas
description: Mundo visual do fluxo "Primeiros passos" do painel do artesão; o caderno de encomendas do ateliê, com capa vermelha, folha pautada e carimbo.
colors:
  caderno-capa: "#b81e0a"
  caderno-capa-escura: "#8f1708"
  caderno-folha: "#fbfaf6"
  caderno-pauta: "#e7e3d6"
  caderno-tinta: "#1d1d1b"
  caderno-carimbo: "#b23a2a"
  texto-grafite: "oklch(37.4% 0.01 67.558)"
  lapis-apagado: "oklch(55.3% 0.013 58.071)"
  papel-branco: "#ffffff"
typography:
  display:
    fontFamily: "Caveat, Karla, cursive"
    fontSize: "2.25rem"
    fontWeight: 600
    lineHeight: 1
  headline:
    fontFamily: "Karla, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.25
  title:
    fontFamily: "Karla, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 700
    lineHeight: 1.5
  body:
    fontFamily: "Karla, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: "1.75rem"
  label:
    fontFamily: "Karla, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 700
    lineHeight: "1.25rem"
  carimbo:
    fontFamily: "Caveat, Karla, cursive"
    fontSize: "1.125rem"
    fontWeight: 600
    lineHeight: 1.25
  carimbo-grande:
    fontFamily: "Caveat, Karla, cursive"
    fontSize: "1.875rem"
    fontWeight: 600
    lineHeight: 1.25
rounded:
  folha: "4px"
  carimbo: "6px"
  capa: "1.75rem"
  pill: "9999px"
spacing:
  capa-borda: "8px"
  capa-borda-sm: "12px"
  folha-margem: "20px"
  folha-margem-sm: "32px"
  pauta: "28px"
  bloco: "24px"
  paragrafo: "16px"
components:
  caderno-capa:
    backgroundColor: "{colors.caderno-capa}"
    textColor: "{colors.papel-branco}"
    rounded: "{rounded.capa}"
    padding: "{spacing.capa-borda}"
  caderno-folha:
    backgroundColor: "{colors.caderno-folha}"
    textColor: "{colors.caderno-tinta}"
    rounded: "{rounded.folha}"
    padding: "16px 20px 24px"
  button-primary:
    backgroundColor: "{colors.caderno-capa}"
    textColor: "{colors.papel-branco}"
    typography: "{typography.title}"
    rounded: "{rounded.pill}"
    padding: "12px 24px"
    height: "48px"
  button-primary-hover:
    backgroundColor: "{colors.caderno-capa-escura}"
    textColor: "{colors.papel-branco}"
  button-capa-ghost:
    textColor: "{colors.papel-branco}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "0 16px"
    height: "44px"
  link:
    textColor: "{colors.caderno-tinta}"
    typography: "{typography.label}"
    height: "44px"
  indice-item:
    textColor: "{colors.caderno-tinta}"
    typography: "{typography.body}"
    rounded: "{rounded.folha}"
    padding: "8px"
    height: "48px"
  carimbo:
    textColor: "{colors.caderno-carimbo}"
    typography: "{typography.carimbo}"
    rounded: "{rounded.carimbo}"
    padding: "0 8px"
  carimbo-grande:
    textColor: "{colors.caderno-carimbo}"
    typography: "{typography.carimbo-grande}"
    rounded: "{rounded.carimbo}"
    padding: "2px 16px"
  nota:
    backgroundColor: "{colors.caderno-pauta}"
    textColor: "{colors.caderno-tinta}"
    typography: "{typography.body}"
    rounded: "{rounded.folha}"
    padding: "12px 16px"
  pendente:
    backgroundColor: "{colors.papel-branco}"
    textColor: "{colors.caderno-tinta}"
    rounded: "{rounded.folha}"
    padding: "12px 16px"
---

# Design System: EloShop — Caderno de Encomendas

## Overview

**Creative North Star: "O Caderno de Encomendas do Ateliê"**

Escopo, sem ambiguidade: este mundo vale **somente** para o fluxo guiado "Primeiros passos" do painel do artesão (`/painel/primeiros-passos/:etapa`, `app/views/seller_portal/getting_started/`). O restante do painel (`/painel`) continua no sistema incumbente do painel: fundo pêssego quente, escala de marca vermelho-laranja `brand-*` (#F33920 no 500), neutros `stone` e as classes `seller-*` (cartões brancos com borda `brand-100`, botões em pílula `brand-600`, campos com foco `brand-500`). A vitrine tem identidade própria e não é descrita aqui. Nenhum token `caderno-*` deve vazar para outras telas do painel, nem os tokens `brand-*`/`seller-*` devem substituir os do caderno dentro do fluxo.

O fluxo é a página do caderno onde o ateliê anota as encomendas: uma capa vermelha da marca envolve uma folha clara, como um caderno aberto; a folha tem pauta fina no passo exato da linha de texto (28px); as etapas feitas são riscadas e recebem um carimbo escrito à mão. Só a etapa atual pede ação, e essa ação fica presa ao pé da tela. O mundo entra por cor, letra, pauta e carimbo; os controles continuam sendo controles web comuns (links, botões em pílula, foco visível), sem imitação de papel em botões e campos.

A densidade é de leitura calma: uma coluna de no máximo 68ch, texto de corpo em 16px com entrelinha de 28px, alvos de toque de 44–48px pensados para o celular na oficina. O fluxo recusa o assistente de SaaS: bolinhas numeradas, barra de progresso azul e pares Voltar/Avançar.

**Key Characteristics:**
- Capa vermelha da marca (#b81e0a) envolvendo uma folha clara pautada.
- Pauta de 28px alinhada à entrelinha do corpo.
- Etapa concluída = texto riscado em vermelho-óxido + carimbo manuscrito "Feito".
- Duas letras: Karla para trabalhar, Caveat só para a mão do artesão.
- Uma ação principal por etapa, fixa no pé da folha.

## Colors

Paleta de caderno: um vermelho de capa, papel quase branco, linha de pauta bege e tinta grafite, com o vermelho-óxido do carimbo como única marca de conclusão.

### Primary
- **Vermelho de Capa** (caderno-capa): faixa da capa que envolve a folha, botão principal da etapa, numeral da etapa no título, palavra "agora" no índice, cor de seleção de texto e anel de foco de todos os controles do caderno. É o `brand-700` da marca, escolhido pelo usuário em 2026-10-15 (substituiu o verde-garrafa do contrato original); texto branco sobre ele fica em ~6,6:1.
- **Capa Escurecida** (caderno-capa-escura): só o hover do botão principal.

### Secondary
- **Vermelho-Óxido de Carimbo** (caderno-carimbo): borda e letra do carimbo "Feito"/"Ateliê pronto", traço que risca a etapa concluída e borda de 2px do aviso de pendência que impede a etapa. Mais apagado e mais terroso que a capa, para ler como tinta de carimbo e não como interface.

### Neutral
- **Folha** (caderno-folha): fundo da folha e da barra de ação fixa.
- **Linha de Pauta** (caderno-pauta): linhas da pauta, divisórias entre itens do índice, borda superior da barra de ação, sublinhado de repouso dos links, fundo da nota "Depois disso" e do hover do índice (a 50%).
- **Tinta Grafite** (caderno-tinta): texto base, títulos, o fio de 2px que separa o índice da etapa aberta.
- **Grafite de Texto** (texto-grafite, `stone-700`): parágrafos corridos da etapa.
- **Lápis Apagado** (lapis-apagado, `stone-500`): numerais do índice e título da etapa já riscada.
- **Papel Branco** (papel-branco): texto sobre a capa e fundo do aviso de pendência, para que ele se destaque da folha.

### Named Rules
**The Capa Rule.** O vermelho de capa emoldura e age: capa, botão principal, numeral da etapa, "agora" e foco. Não vira fundo de blocos de conteúdo dentro da folha.

**The Carimbo Rule.** O vermelho-óxido marca o que terminou (carimbo, risco) e, como borda, o único estado que impede a etapa. Nunca aparece em botões, links ou títulos.

## Typography

**Display Font:** Caveat SemiBold 600 (com Karla, cursive)
**Body Font:** Karla variável 200–800 (com ui-sans-serif, system-ui, sans-serif)

**Character:** Karla é uma grotesca de trabalho com desenho levemente artesanal, legível no corpo e firme em negrito; Caveat é a letra de quem escreve no caderno e aparece em pouquíssimos pontos. As duas são servidas pelo próprio app (subconjunto latino, `app/assets/fonts/`, OFL), porque a CSP só permite `font-src 'self'`; `font-display: swap`.

### Hierarchy
- **Display** (Caveat 600, 2.25rem, entrelinha 1): só o título "Primeiros passos" na capa.
- **Headline** (Karla 700, 1.5rem no celular, 1.875rem a partir de 640px, entrelinha 1.25): título da etapa aberta, precedido do numeral em vermelho de capa ("2.").
- **Title** (Karla 700, 1rem): subtítulos dentro da etapa ("Como a conexão funciona") e o rótulo do botão principal.
- **Body** (Karla 400, 1rem, entrelinha 28px, máx. 68ch): parágrafos e listas da etapa, e os itens do índice (o atual em 700).
- **Label** (Karla 700, 0.875rem): contagem "N de 5 etapas concluídas", botão fantasma da capa e links secundários.
- **Carimbo** (Caveat 600, 1.125rem; 1.875rem no carimbo grande): texto do carimbo e a marca "agora" (1.25rem) da etapa atual.

### Named Rules
**The Mão Rule.** Caveat só onde o artesão escreveria à mão: o título da capa, o carimbo e o "agora" do índice. Nunca em texto corrido, botões, rótulos ou títulos de etapa.

**The Pauta Rule.** O corpo dentro da pauta tem entrelinha de exatamente 28px (`leading-7`), o mesmo passo da pauta; mudar uma sem a outra desalinha a linha da base do texto.

## Layout

Uma única coluna com largura máxima de 48rem (`max-w-3xl`) dentro da área de conteúdo do painel. A capa tem 8px de borda vermelha em volta da folha (12px a partir de 640px) e, acima da folha, uma faixa com o título à esquerda e, à direita, a contagem e o botão do tour; no celular a faixa quebra em linhas. A folha tem margem interna de 20px (32px a partir de 640px), 16px no topo e 24px no pé (32px a partir de 640px).

Ordem da folha: índice das cinco etapas (itens de no mínimo 48px, separados por linhas de pauta, numeral à esquerda e carimbo ou "agora" à direita); fio de 2px em tinta; etapa aberta com título e, abaixo dele, o bloco pautado. A pauta é um gradiente repetido de 28px começando 1rem abaixo do topo do bloco, alinhado à primeira linha de texto; o bloco usa `flow-root` para que a margem do primeiro parágrafo não escape e desloque a pauta. Texto corrido limitado a 68ch.

Ritmo: 16px antes do primeiro parágrafo, 12px entre parágrafos seguidos, 24px antes de subtítulos e da barra de ação. A barra de ação (`caderno-acoes`) é `sticky` no pé da tela em qualquer largura, sangra até as bordas da folha, tem fundo de folha e borda superior em pauta; no celular empilha botão e link, a partir de 640px coloca-os em linha. Um único ponto de quebra: 640px.

## Elevation & Depth

Quase plano. O caderno inteiro tem uma única sombra ambiente, curta e larga, em tinta grafite; folha, nota e barra de ação não têm sombra e se separam por cor e por linha. A profundidade principal é a da capa vermelha em volta da folha clara.

### Shadow Vocabulary
- **Caderno sobre a mesa** (`box-shadow: 0 1px 2px rgba(29,29,27,0.06), 0 16px 40px rgba(29,29,27,0.10)`): só no contêiner do caderno.

### Named Rules
**The Uma Sombra Rule.** Uma sombra, no caderno. Nada dentro da folha se eleva; separação interna é feita por pauta, fio e fundo.

## Shapes

Contraste de cantos: a capa é generosamente arredondada (1.75rem), como capa dura de canto gasto; a folha, a nota e o aviso de pendência têm cantos quase retos (4px), como papel. Botões são pílulas completas. O carimbo é um retângulo de cantos suaves (6px) com borda de 2px (3px no grande), girado −3° (−4° no grande), a única forma inclinada do sistema. Linhas: pauta de 1px, divisórias de 1px em pauta, fio de 2px em tinta entre índice e etapa, risco de 2px em vermelho-óxido nas etapas feitas.

## Components

### Buttons
- **Shape:** pílula (9999px), altura mínima de 48px.
- **Primary (`caderno-botao`):** vermelho de capa com texto branco, Karla 700 1rem, 12px × 24px. Uma por etapa, na barra de ação fixa; em largura total no celular quando o rótulo é longo.
- **Hover / Focus:** hover escurece para a capa escurecida; foco com contorno de 2px em vermelho de capa, afastado 2px. Transição de cor padrão (150ms).
- **Fantasma da capa:** só na faixa da capa (tour do painel): borda branca a 40%, texto branco Karla 700 0.875rem, altura de 44px; hover com branco a 10% no fundo.

### Links
- **Style (`caderno-link`):** Karla 700 0.875rem em tinta, sublinhado de 2px em pauta afastado 4px, altura mínima de 44px. Ação secundária da etapa ou ação de revisar quando a etapa já está feita.
- **Hover / Focus:** o sublinhado passa para vermelho de capa; foco com contorno de 2px em vermelho de capa.

### Cards / Containers
- **Caderno:** capa vermelha (1.75rem de raio) com a sombra única, envolvendo a folha.
- **Folha:** fundo de folha, 4px de raio, sem borda nem sombra.
- **Nota "Depois disso" (`caderno-nota`):** fundo em linha de pauta, 4px de raio, 12px × 16px, corpo de 28px; diz o que a etapa destrava.
- **Pendência (`caderno-pendente`):** fundo branco, borda de 2px em vermelho-óxido, Karla 600; só para o estado que impede a etapa (ex.: conexão ainda não configurada pela plataforma), substituindo a ação.

### Navigation
- **Índice das etapas (`caderno-indice`):** lista ordenada com `aria-label`; cada item é um link de no mínimo 48px, numeral em lápis apagado, título curto em corpo. Etapa atual em 700, com `aria-current="step"` e "agora" em Caveat vermelho de capa à direita. Etapa feita: título em lápis apagado riscado em vermelho-óxido, carimbo "Feito" à direita (decorativo, `aria-hidden`) e "(feita)" para leitores de tela. Hover com fundo em pauta a 50%; foco com contorno vermelho de capa.

### Carimbo (signature)
Retângulo inclinado com borda e letra Caveat em vermelho-óxido. Pequeno ("Feito") no índice; grande ao lado do título de uma etapa concluída e no fechamento "Ateliê pronto", quando todas as etapas estão feitas. Só significa conclusão.

### Barra de ação (`caderno-acoes`)
Presa ao pé da tela, fundo de folha, borda superior em pauta. Contém a ação principal da etapa e, opcionalmente, um link secundário; ou o aviso de pendência no lugar da ação. Quando a etapa atual já está feita e há outra pendente, o fim da etapa oferece "Próxima etapa: …" como botão principal.

## Do's and Don'ts

### Do:
- **Do** restringir os tokens `caderno-*` e as classes `.caderno*` ao fluxo "Primeiros passos"; o resto do painel segue `brand-*`/`seller-*`.
- **Do** manter a entrelinha do corpo pautado em 28px, igual ao passo da pauta.
- **Do** marcar etapa concluída com texto + risco + carimbo, nunca só por cor, e anunciar "(feita)" para leitores de tela.
- **Do** dar a cada etapa uma única ação principal (`caderno-botao`), na barra fixa do pé.
- **Do** usar o contorno de foco de 2px em vermelho de capa em todo controle do caderno.
- **Do** servir fontes do próprio app (`app/assets/fonts/`), registrando origem e licença em `CREDITS.md`.

### Don't:
- **Don't** usar bolinhas numeradas, barra de progresso ou pares Voltar/Avançar de assistente de SaaS neste fluxo.
- **Don't** usar Caveat fora do título da capa, do carimbo e do "agora".
- **Don't** usar o carimbo ou o vermelho-óxido para algo que não seja conclusão (carimbo, risco) ou o aviso que impede a etapa (borda).
- **Don't** adicionar sombras dentro da folha; a única sombra é a do caderno.
- **Don't** carregar fontes de CDN externo; a CSP só permite `font-src 'self'`.
