---
name: EloShop — Painel do Artesão
description: Sistema visual do painel do artesão (/painel), inclusive o fluxo "Primeiros passos": fundo pêssego quente, cartões brancos, vermelho da marca na ação e neutros stone.
colors:
  brand-50: "#fef2f0"
  brand-100: "#fde1dd"
  brand-200: "#fbbeb6"
  brand-500: "#f33920"
  brand-600: "#df240c"
  brand-700: "#b81e0a"
  fundo-pessego: "#fdf1e7"
  papel: "#ffffff"
  tinta: "#0c0a09"
  texto: "#44403c"
  texto-apoio: "#57534e"
  texto-apagado: "#78716c"
  linha: "#e7e5e4"
  borda-campo: "#d6d3d1"
  feito: "#059669"
  feito-fundo: "#d1fae5"
  feito-texto: "#065f46"
  atencao-fundo: "#fffbeb"
  atencao-texto: "#78350f"
  bloqueio-fundo: "#fee2e2"
  bloqueio-texto: "#991b1b"
typography:
  display:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.875rem"
    fontWeight: 900
    lineHeight: 1.2
    letterSpacing: "-0.025em"
  headline:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.25
  title:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.25rem"
    fontWeight: 700
    lineHeight: 1.4
  body:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: "1.75rem"
  body-sm:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: "1.25rem"
  label:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 700
    lineHeight: "1.25rem"
  etiqueta:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 600
    lineHeight: "1rem"
rounded:
  reto: "0px"
  campo: "0.75rem"
  cartao: "1rem"
  cartao-grande: "2rem"
  pill: "9999px"
spacing:
  campo-x: "12px"
  campo-y: "8px"
  cartao: "24px"
  cartao-grande: "32px"
  secao: "24px"
  pagina: "32px"
components:
  button-primary:
    backgroundColor: "{colors.brand-600}"
    textColor: "{colors.papel}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "12px 24px"
    height: "44px"
  button-primary-hover:
    backgroundColor: "{colors.brand-700}"
    textColor: "{colors.papel}"
  button-secondary:
    backgroundColor: "{colors.papel}"
    textColor: "{colors.brand-700}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "12px 24px"
    height: "44px"
  button-secondary-hover:
    backgroundColor: "{colors.brand-50}"
    textColor: "{colors.brand-700}"
  card:
    backgroundColor: "{colors.papel}"
    textColor: "{colors.tinta}"
    rounded: "{rounded.cartao}"
    padding: "{spacing.cartao}"
  card-lg:
    backgroundColor: "{colors.papel}"
    textColor: "{colors.tinta}"
    rounded: "{rounded.cartao-grande}"
    padding: "{spacing.cartao-grande}"
  input:
    backgroundColor: "{colors.brand-50}"
    textColor: "{colors.tinta}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.campo}"
    padding: "8px 12px"
  badge:
    typography: "{typography.etiqueta}"
    rounded: "{rounded.pill}"
    padding: "2px 10px"
  step-segment:
    backgroundColor: "{colors.papel}"
    textColor: "{colors.tinta}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.reto}"
    padding: "12px"
  step-segment-current:
    backgroundColor: "{colors.brand-50}"
    textColor: "{colors.tinta}"
---

# Design System: EloShop — Painel do Artesão

## Overview

**Creative North Star: "A bancada organizada do ateliê"**

Escopo: todo o painel do artesão (`/painel`), inclusive o fluxo "Primeiros passos" (`/painel/primeiros-passos`). A vitrine pública e a administração da plataforma têm sistemas próprios e não são descritas aqui.

O painel é ferramenta de trabalho, usada com frequência no celular, na oficina, com uma mão e sob luz forte. A densidade é de leitura calma: cartões brancos sobre um fundo pêssego quente, um título forte por tela e uma ação principal vermelha. O painel responde primeiro "tenho pedido para enviar e quanto vou receber?"; a configuração vem depois.

Até 2026-10-22 o "Primeiros passos" tinha um mundo próprio (o "Caderno de Encomendas", com capa vermelha, folha pautada, carimbo manuscrito e as fontes Karla e Caveat). Ele foi retirado a pedido do usuário: o fluxo segue o mesmo padrão do resto do painel. A Karla saiu do app; a Caveat continua só como fonte de título "Manuscrita" da vitrine (`SellerTheme::HEADING_FONTS`), nunca no painel.

**Key Characteristics:**
- Fundo em degradê pêssego (`brand-50` para `#fdf1e7`), topo branco fixo e menu lateral a partir de `lg`.
- Cartões brancos com borda `brand-100` (`.seller-card`, `.seller-card-lg`).
- Vermelho da marca só na ação principal e no destaque da etapa atual; vermelho de alerta só no que bloqueia a venda.
- Estado sempre em texto, nunca só por cor ("Feito", "Agora", "Obrigatório", "Pendente").
- Fonte do sistema (sem fonte servida pelo app).

## Colors

Uma escala de marca vermelho-laranja (`brand-*`, extraída da logo, #F33920 no 500), neutros `stone` quentes e três cores de estado (verde, âmbar, vermelho).

### Primary
- **Vermelho de Ação** (brand-600, #df240c): botão principal (`.seller-button--primary`), número da etapa atual. Texto branco sobre ele a 4,8:1.
- **Vermelho Profundo** (brand-700, #b81e0a): hover do botão principal, texto de botão secundário, etiqueta "Agora", número do título da etapa.
- **Rosado de Destaque** (brand-50/100/200): fundo da etapa atual, das notas ("Depois disso") e do hover; bordas de cartão (`brand-100`) e de botão secundário (`brand-200`).

### Neutral
- **Fundo Pêssego** (`brand-50` → `#fdf1e7`): fundo de todas as telas do painel.
- **Papel** (#ffffff): cartões, topo, faixa de etapas.
- **Tinta** (stone-950): títulos. **Texto** (stone-700): parágrafos. **Apoio** (stone-600): legendas e contagens. **Apagado** (stone-500): números de etapa pendente.

### Estado
- **Feito** (emerald-600 traço/ícone, emerald-100 fundo, emerald-800 texto): etapa concluída, conta aprovada.
- **Atenção** (amber-50 fundo, amber-900 texto): pendência que espera a plataforma ou o artesão, sem bloquear.
- **Bloqueio** (red-100 fundo, red-800 texto): só o que impede a venda ("Obrigatório").

### Named Rules
**The Um Vermelho Rule.** Por tela, um botão vermelho cheio (a ação principal); o resto é secundário ou link.

**The Estado em Texto Rule.** Cor de estado sempre acompanha uma palavra ("Feito", "Agora", "Pendente") ou um ícone com texto para leitor de tela.

## Typography

**Fonte:** a do sistema (`ui-sans-serif, system-ui, sans-serif`), padrão do Tailwind. O painel não serve fonte própria.

### Hierarchy
- **Display** (900, 1.875rem, `tracking-tight`): título da tela (`h1`), ex.: "Visão geral", "Primeiros passos".
- **Headline** (700, 1.5rem): título de seção ou da etapa aberta.
- **Title** (700, 1.25rem): título de cartão ("Para começar a vender").
- **Body** (400, 1rem, entrelinha 28px, máx. 68ch): texto corrido das etapas.
- **Body-sm** (400, 0.875rem): legendas, linhas de lista, campos.
- **Label** (700, 0.875rem): botões e links de ação.
- **Etiqueta** (600, 0.75rem): `.seller-badge`; nas etiquetas retas da faixa de etapas, 0.6875rem em caixa alta.

## Layout

Coluna de conteúdo com `max-w-7xl`; menu lateral de 15rem fixo a partir de `lg` e, abaixo disso, menu no hambúrguer do topo. Telas de leitura (Primeiros passos) limitam o conteúdo a `max-w-3xl`. Ritmo vertical de 24–32px entre blocos (`space-y-6`/`space-y-8`). Um ponto de quebra principal (`lg`, 1024px) para o menu e `sm` (640px) para empilhar ações.

## Elevation & Depth

Quase plano. Cartões com sombra curta e larga em tom quente (`.seller-card-lg`: `0 1px 2px rgba(120,40,10,0.03), 0 16px 40px rgba(120,40,10,0.05)`; `.seller-card`: `shadow-sm`). Nada dentro de um cartão se eleva; separação interna por linha `brand-100`.

## Shapes

Botões e etiquetas em pílula; campos com 0.75rem; cartões com 1rem (`.seller-card`) ou 2rem (`.seller-card-lg`). Exceção deliberada: a faixa de etapas dos Primeiros passos é reta (0px), com segmentos horizontais e etiquetas retas, pedido do usuário em 2026-10-22.

## Components

### Buttons
- **Primary (`.seller-button .seller-button--primary`):** vermelho de ação, texto branco, pílula, altura mínima de 44px. Hover em brand-700.
- **Secondary (`.seller-button .seller-button--secondary`):** borda brand-200, texto brand-700, fundo transparente; hover brand-50.
- **Link de ação:** texto stone-700 em negrito, sublinhado stone-300 afastado 4px, altura mínima de 44px; hover brand-700.

### Cards
- **`.seller-card`:** branco, borda brand-100, 1rem de raio, 24px de margem interna.
- **`.seller-card-lg`:** o mesmo com 2rem de raio e 32px de margem a partir de `sm`.
- **Nota:** fundo brand-50, raio 0.75rem, 12px × 16px (ex.: "Depois disso").
- **Pendência:** fundo amber-50, borda amber-200, texto amber-900.

### Inputs
- **`.seller-input`:** borda stone-300, fundo brand-50/30, raio 0.75rem; foco com borda brand-500, fundo branco e anel brand-200. Rótulo `.seller-label` (600, 0.875rem, stone-700).

### Badges
- **`.seller-badge`:** pílula 0.75rem/600; cores pelas regras de estado.

### Faixa de etapas (Primeiros passos)
Lista ordenada horizontal, segmentos retos separados por linha brand-100, num contorno brand-100 sobre branco. Traço de 4px no topo de cada segmento: emerald-600 feita, brand-600 atual, stone-200 pendente. A atual tem fundo brand-50, `aria-current="step"` e etiqueta reta "Agora"; a feita, etiqueta reta "Feito" e "(feita)" para leitor de tela.
- **Celular:** os cinco segmentos lado a lado só com o número (ou ✓), altura de 56px, nome completo em `sr-only`; abaixo da faixa, uma linha "Etapa N de 5: nome".
- **A partir de `sm`:** cada segmento mostra "Etapa N", a etiqueta e o nome curto; a faixa rola na horizontal se não couber (largura mínima de 9.5rem por segmento). A lista é `relative` para conter o texto `sr-only` absoluto dentro da rolagem.

## Do's and Don'ts

### Do:
- **Do** usar as classes `seller-*` para cartões, botões, campos e etiquetas do painel.
- **Do** manter um botão vermelho cheio por tela.
- **Do** escrever o estado em texto além da cor.
- **Do** garantir alvos de toque de 44px e contraste AA (4,5:1 no texto).

### Don't:
- **Don't** trazer de volta o mundo do caderno (capa, pauta, carimbo, Karla, Caveat no painel) nem outro mundo próprio por tela sem pedido explícito.
- **Don't** usar vermelho de alerta para o que não bloqueia a venda.
- **Don't** reintroduzir pílulas ou cantos arredondados na faixa de etapas dos Primeiros passos.
- **Don't** depender de fonte ou script de CDN externo (a CSP só aceita o próprio app).
