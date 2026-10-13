# Atrás da Railway (e do Cloudflare), `request.remote_ip` é o IP do proxy
# interno (100.64.0.x), que muda a cada requisição. Todo `rate_limit` do Rails
# chaveia por `remote_ip`, então um atacante com um IP só caía em baldes
# diferentes e nunca chegava ao limite (spam no formulário de contato em
# 2026-10-13).
#
# A Railway preenche `X-Real-IP` com o IP do cliente e sobrescreve o valor que
# o cliente mandar — verificado em produção em 2026-10-13, com `X-Real-IP` e
# `X-Forwarded-For` forjados direto no domínio *.up.railway.app. Já
# `CF-Connecting-IP` NÃO serve: o valor forjado passa intacto.
class RealClientIp
  def initialize(app)
    @app = app
  end

  def call(env)
    ip = parse(env["HTTP_X_REAL_IP"])
    env["action_dispatch.remote_ip"] = ip if ip
    @app.call(env)
  end

  private

  # Só aceita um IP válido; qualquer outra coisa cai no comportamento padrão.
  def parse(value)
    IPAddr.new(value.to_s.strip).to_s
  rescue IPAddr::Error
    nil
  end
end

Rails.application.config.middleware.insert_after ActionDispatch::RemoteIp, RealClientIp
