# Be sure to restart your server when you modify this file.
#
# A aplicação não carrega nenhum script, estilo, fonte ou imagem de origem
# externa (importmap vendoriza tudo localmente, Tailwind é compilado num
# único arquivo local) — ver docs/security.md. Por isso a política pode ser
# estrita: só a própria origem, mais `data:` para imagens (necessário para
# SVGs/ícones embutidos).
#
# Exceção (Fase 24): o Card Payment Brick do Mercado Pago. Os domínios abaixo
# saíram da leitura do próprio SDK oficial servido em
# https://sdk.mercadopago.com/js/v2 — cada um está na diretiva que
# corresponde ao uso que o SDK faz dele, e não em todas:
#
#   sdk.mercadopago.com          loader <script> da view; também serve
#                                /op-pay/prapi/index.html num iframe
#   api-static.mercadopago.com   `sourceUrl` dos secure fields (o código dos
#                                campos de cartão)
#   http2.mlstatic.com           `assetsBaseUrl` do bundle do Brick
#                                (/frontend-assets/op-cho-bricks) e os logos
#                                de bandeira (/storage/logos-api-admin/*.png)
#   secure-fields.mercadopago.com  `cacheUrl`: o iframe que hospeda os campos
#                                de cartão — frame-src E connect-src (o SDK
#                                também faz XHR para ele), nunca script-src
#   api.mercadopago.com          chamadas XHR do Brick (/v1, /v2, /bricks,
#                                /op-pay/web/v1, /op-frontend-metrics/v1)
#   api.mercadolibre.com         telemetria melidata (/tracks)
#
# Os domínios `-stg` (secure-fields-stg) aparecem no SDK apenas nos perfis
# test1/test2 e não são liberados: produção usa o perfil `prod`. Se o Brick
# quebrar no sandbox, é aqui que se olha primeiro.
#
# Isto substitui o `https://*.mercadopago.com`/`https://*.mlstatic.com` amplo
# da primeira entrega da Fase 24. O curinga cobria qualquer subdomínio dos
# dois (inclusive os de conteúdo do Mercado Livre), o que é bem mais do que
# o Brick precisa. VERIFICADO NUM BROWSER EM 2026-09-12, com
# vendedor real: a lista de domínios estava certa, mas faltavam dois usos que
# a leitura do bundle não revelou — o script inline do antifraude, resolvido
# passando `deviceProfileCspNonce` ao SDK (ver o controller do Brick), e o XHR
# para secure-fields, acrescentado ao connect-src. Segue valendo a regra: se o
# console acusar bloqueio, acrescente o domínio à diretiva específica — nunca
# volte ao curinga.
Rails.application.configure do
  mercado_pago_sdk    = "https://sdk.mercadopago.com"
  mercado_pago_static = "https://api-static.mercadopago.com"
  mercado_pago_api    = "https://api.mercadopago.com"
  mercado_pago_fields = "https://secure-fields.mercadopago.com"
  mercado_libre_api   = "https://api.mercadolibre.com"
  mercado_libre_cdn   = "https://http2.mlstatic.com"

  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self
    policy.img_src     :self, :data, mercado_libre_cdn
    policy.object_src  :none
    policy.script_src  :self, mercado_pago_sdk, mercado_pago_static, mercado_libre_cdn
    # `unsafe_inline` e não um domínio: o SDK não busca nenhum .css externo
    # (zero referências a stylesheet no bundle), mas injeta <style> em
    # runtime — o spinner de carregamento, o botão de fechar e os estilos do
    # container do Brick. Esses <style> são criados por código de terceiro e
    # não carregam nonce (o SDK só aceita nonce para o script do antifraude,
    # via `deviceProfileCspNonce`; para <style> não há opção equivalente), então
    # nenhum curinga de domínio jamais os liberaria: para estilo inline o que
    # conta é `unsafe-inline`, e ele só vale se a diretiva NÃO tiver nonce
    # (o browser ignora `unsafe-inline` quando há nonce). Por isso style-src
    # saiu de `content_security_policy_nonce_directives` abaixo.
    #
    # O afrouxamento é real e vale reconhecer: qualquer estilo inline passa a
    # ser aceito. O risco é contido — CSS injetado não executa script, o
    # `script_src` segue com nonce e sem `unsafe-inline`, e a aplicação não
    # tem nenhum <style> próprio em view (só o mailer, fora do alcance da
    # CSP). A alternativa seria hashear cada bloco do SDK, que muda a cada
    # release deles e quebraria o checkout sem aviso.
    policy.style_src   :self, :unsafe_inline
    # `mercado_pago_fields` também em connect-src, não só em frame-src: além de
    # hospedar o iframe dos campos, o SDK faz XHR para esse mesmo domínio ao
    # montar o Brick (`fetchPage`). Observado no console em 2026-09-12 —
    # "Connecting to 'https://secure-fields.mercadopago.com/' violates ...
    # connect-src". Não afrouxa nada: é o domínio que já confiamos para o
    # iframe, agora na diretiva que o outro uso exige.
    policy.connect_src :self, mercado_pago_api, mercado_pago_static, mercado_pago_fields, mercado_libre_cdn, mercado_libre_api
    policy.frame_src   :self, mercado_pago_fields, mercado_pago_sdk
    policy.base_uri    :self
    policy.form_action :self
  end

  # Nonce por requisição (memoizado pelo Rails, não muda dentro da mesma
  # requisição) — necessário para o script inline do importmap. Não usar
  # request.session.id: fica em branco em requisições sem sessão iniciada.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  # Só script-src: style-src usa `unsafe-inline` para os <style> que o SDK do
  # Mercado Pago injeta, e a presença de nonce na diretiva faria o browser
  # ignorar justamente esse `unsafe-inline` (ver comentário acima).
  config.content_security_policy_nonce_directives = %w[script-src]
end
