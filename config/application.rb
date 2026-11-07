require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Eloshop
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # A loja opera no Brasil: as telas mostram o horário de Brasília. O banco
    # continua gravando em UTC (`active_record.default_timezone`), então só
    # muda como as datas são exibidas e onde cai a virada do dia.
    config.time_zone = "Brasilia"
    # config.eager_load_paths << Rails.root.join("extras")

    # A loja vende em reais para o Brasil: o locale define o símbolo e a
    # pontuação do dinheiro em um lugar só. Antes cada view passava
    # `unit: product.currency`, o que punha o código ISO no lugar do símbolo
    # e imprimia "BRL249.00" em vez de "R$ 249,00".
    config.i18n.default_locale = :"pt-BR"
    config.i18n.available_locales = [ :"pt-BR", :en ]

    # pt-BR.yml traduz só o formato do dinheiro. Sem este fallback, toda
    # mensagem de validação viraria "Translation missing" — o Rails traz as
    # dela apenas em inglês, e é de lá que elas continuam vindo.
    config.i18n.fallbacks = [ :en ]

    # Cotação de frete em provedor externo (Shipping::Providers). Ligada fora
    # de produção, onde os testes e o sandbox dependem dela; produção decide
    # pela variável de ambiente (ver config/environments/production.rb).
    config.x.shipping.remote_quotes_enabled = true
    # Compra de etiqueta pela carteira do ateliê (ShippingLabels). Mesma
    # lógica: ligada fora de produção, decidida por variável em produção.
    config.x.shipping.labels_enabled = true
    # Cadastro de distribuidor em /atacado/cadastro (ADR 007, Fase 25). Ligado
    # fora de produção para testar no localhost; em produção fica desligado
    # até o advogado revisar os termos do distribuidor (decisão do Uriel,
    # 2026-11-07), e quem decide é a variável de ambiente.
    config.x.distributors.signup_enabled = true
  end
end
