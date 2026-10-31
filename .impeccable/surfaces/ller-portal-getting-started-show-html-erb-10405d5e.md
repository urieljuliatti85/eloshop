---
version: 1
slug: "ller-portal-getting-started-show-html-erb-10405d5e"
primary_target: "app/views/seller_portal/getting_started/show.html.erb"
related_targets: []
---

# Fluxo guiado de primeiros passos (painel do artesão)

Escopo: o passo a passo de configuração do ateliê (endereço, conta do Mercado Pago, chave PIX, primeira peça, aprovação), uma etapa por tela. Modo: Operate. Usuário: artesão no celular, na oficina, configurando pela primeira vez. Tarefa: concluir a próxima etapa e saber o que falta. Restrições: textos e ordem dos fluxos do Mercado Pago e da chave PIX só mudam com aprovação; CSP sem CDN; o tour localiza passos pelos links do menu.

## Direction contract

THESIS: O passo a passo segue o padrão do painel (DESIGN.md): título forte, faixa de etapas e a etapa aberta num cartão branco, com uma ação principal vermelha. O mundo do caderno de encomendas (capa, pauta, carimbo, Karla e Caveat) foi retirado em 2026-10-22 a pedido do usuário.

FORM: Faixa horizontal de segmentos retos, sem pílulas nem cantos arredondados (pedido do usuário em 2026-10-22). Traço de 4px no topo de cada segmento diz o estado: verde feita, vermelho atual, cinza pendente; a atual com fundo brand-50 e etiqueta reta "Agora", a feita com etiqueta reta "Feito".

FIRST VIEWPORT: No celular, "Primeiros passos" e "N de 5 etapas concluídas", o botão do tour, a faixa com os cinco segmentos lado a lado só com número ou ✓, a linha "Etapa N de 5: nome" e o início do cartão da etapa atual.

STORY: O artesão vê de relance o que já fez e o que falta, abre uma etapa por vez e sabe o que cada etapa destrava ("Depois disso").
