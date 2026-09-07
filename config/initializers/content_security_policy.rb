# Be sure to restart your server when you modify this file.
#
# A aplicação não carrega nenhum script, estilo, fonte ou imagem de origem
# externa (importmap vendoriza tudo localmente, Tailwind é compilado num
# único arquivo local) — ver docs/security.md. Por isso a política pode ser
# estrita: só a própria origem, mais `data:` para imagens (necessário para
# SVGs/ícones embutidos).
#
# Exceção (Fase 24): o Card Payment Brick do Mercado Pago carrega
# https://sdk.mercadopago.com/js/v2 (confirmado na fonte oficial,
# github.com/mercadopago/sdk-js), que por sua vez injeta iframes e faz
# chamadas para tokenizar o cartão — sem lista oficial e definitiva de todos
# os subdomínios usados internamente. `*.mercadopago.com`/`*.mlstatic.com`
# (CDN estático do Mercado Livre/Mercado Pago) é deliberadamente amplo por
# ora: TODO — apertar para os domínios exatos observados no console do
# browser depois de rodar o Brick em desenvolvimento/sandbox (débito técnico,
# ver CLAUDE.md §7; motivo: falta de documentação oficial completa; impacto:
# CSP mais permissiva que o necessário só nessas diretivas; prioridade: antes
# de habilitar cartão em produção).
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self, "https://*.mercadopago.com", "https://*.mlstatic.com"
    policy.style_src   :self, "https://*.mercadopago.com"
    policy.connect_src :self, "https://*.mercadopago.com"
    policy.frame_src   :self, "https://*.mercadopago.com"
    policy.base_uri    :self
    policy.form_action :self
  end

  # Nonce por requisição (memoizado pelo Rails, não muda dentro da mesma
  # requisição) — necessário para o script inline do importmap. Não usar
  # request.session.id: fica em branco em requisições sem sessão iniciada.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
