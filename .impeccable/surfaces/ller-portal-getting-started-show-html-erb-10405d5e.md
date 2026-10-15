---
version: 1
slug: "ller-portal-getting-started-show-html-erb-10405d5e"
primary_target: "app/views/seller_portal/getting_started/show.html.erb"
related_targets: []
---

# Fluxo guiado de primeiros passos (painel do artesão)

Escopo: o passo a passo de configuração do ateliê (endereço, conta do Mercado Pago, chave PIX, primeira peça, aprovação), uma etapa por tela. Modo: Operate. Usuário: artesão no celular, na oficina, configurando pela primeira vez. Tarefa: concluir a próxima etapa e saber o que falta. Restrições: textos e ordem dos fluxos do Mercado Pago e da chave PIX só mudam com aprovação; CSP sem CDN (fontes servidas pelo app); o tour localiza passos pelos links do menu.

## Direction contract

THESIS: O passo a passo é a página do caderno de encomendas do ateliê: cada etapa concluída é riscada e recebe um carimbo, e só a etapa atual pede ação. Recusa o assistente de SaaS com bolinhas numeradas, barra azul e botões Voltar/Avançar.

OWN-WORLD: Faixa de capa vermelha da marca (#b81e0a, troca pedida pelo usuário em 2026-10-15; era verde-garrafa) como cor do fluxo; folha clara (#fbfaf6) com pauta fina e discreta; tinta grafite (#1d1d1b); carimbo vermelho-óxido (#b23a2a) só para etapa concluída. Uma sans de trabalho para a interface e uma letra manuscrita só no título da folha e no carimbo. Controles web padrão.

STORY: O artesão vê de relance o que já fez e o que falta, faz uma etapa por vez, ganha o carimbo quando conclui e sabe o que cada etapa destrava.

FIRST VIEWPORT: No celular, faixa vermelha com "Primeiros passos" e "N de 5"; a folha com as cinco etapas em lista (prontas riscadas, a atual marcada); o carimbo da última concluída; título, texto e prova da etapa atual; botão principal vermelho fixo no pé da tela.

FORM: Caderno de Encomendas, posição 1 da lista ordenada (escolha do usuário pelo card IMPECCABLE’S PICK). seed: none (unavailable)

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
