# Be sure to restart your server when you modify this file.

# Só ativa em produção com DSN configurado — sem credencial, o SDK simplesmente
# não envia nada (comportamento padrão do sentry-ruby), então isso é defensivo
# apenas para não exigir a credencial em development/test/CI.
if Rails.env.production? && ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

    # Amostragem de performance: baixa por padrão para não inflar custo/volume
    # em um app com tráfego de e-commerce; ajuste conforme o plano do Sentry.
    config.traces_sample_rate = 0.1

    # Nunca envie corpo de request/response — pode conter endereço, e-mail,
    # dados de pagamento. filter_parameters já cobre os parâmetros marcados
    # como sensíveis; aqui garantimos que nem o payload bruto vaza.
    config.send_default_pii = false
  end
end
