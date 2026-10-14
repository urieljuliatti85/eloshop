# Defesas dos formulários abertos que disparam e-mail: o captcha (Turnstile) e
# um teto global por dia. A cota do Resend é única e compartilhada com os
# e-mails de pedido e pagamento, que não podem parar por causa de spam.
module EmailAbuseProtection
  extend ActiveSupport::Concern

  TURNSTILE_ERROR = "Não conseguimos confirmar que você é uma pessoa. Tente de novo.".freeze

  # Domínio novo ainda sem reputação: os primeiros e-mails podem cair no spam.
  SPAM_HINT = "Se o e-mail não chegar em alguns minutos, olhe também a caixa de spam.".freeze

  # Teto diário combinado dos e-mails de conta (boas-vindas e redefinição de
  # senha): o restante da cota fica reservado para pedidos.
  DAILY_ACCOUNT_EMAIL_LIMIT = 40

  private

  # Falha aberta se o Cloudflare estiver fora do ar: o formulário não para por
  # causa de um terceiro, e os tetos diários seguem valendo.
  def turnstile_passed?
    case Turnstile.verify(params["cf-turnstile-response"], remote_ip: request.remote_ip)
    when :ok then true
    when :unavailable
      Rails.logger.warn("turnstile_unavailable")
      true
    else false
    end
  end

  def within_daily_budget?(name, limit)
    key = "email_budget:#{name}:#{Date.current.iso8601}"
    Rails.cache.write(key, 0, unless_exist: true, expires_in: 2.days)
    Rails.cache.increment(key).to_i <= limit
  end

  # `true` se ainda há cota para mais um e-mail de conta hoje.
  def account_email_budget_available?
    within_daily_budget?("account", DAILY_ACCOUNT_EMAIL_LIMIT).tap do |ok|
      Rails.logger.warn("account_email_daily_limit_reached") unless ok
    end
  end
end
