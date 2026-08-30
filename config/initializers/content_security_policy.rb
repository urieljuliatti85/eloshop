# Be sure to restart your server when you modify this file.
#
# A aplicação não carrega nenhum script, estilo, fonte ou imagem de origem
# externa (importmap vendoriza tudo localmente, Tailwind é compilado num
# único arquivo local) — ver docs/security.md. Por isso a política pode ser
# estrita: só a própria origem, mais `data:` para imagens (necessário para
# SVGs/ícones embutidos).
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.connect_src :self
    policy.base_uri    :self
    policy.form_action :self
  end

  # Nonce por requisição (memoizado pelo Rails, não muda dentro da mesma
  # requisição) — necessário para o script inline do importmap. Não usar
  # request.session.id: fica em branco em requisições sem sessão iniciada.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
