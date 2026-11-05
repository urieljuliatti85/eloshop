ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/shipping_label_test_helper"

module ActiveSupport
  class TestCase
    # Paralelização por fork trava de forma reproduzível neste ambiente assim
    # que a suíte passa de 50 testes (o processo forkado nunca retoma após o
    # check de schema do Active Record). Desativada até a causa raiz ser
    # investigada — ver nota na Fase 3 do ROADMAP.md.
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # cache_store é :memory_store em teste (ver config/environments/test.rb)
    # para permitir testar rate_limit de verdade — sem isso, contadores de
    # um teste vazariam para o próximo (mesmo IP de teste em todos).
    setup { Rails.cache.clear }

    # Destinatário válido para checkout com entrega (CPF exigido): ver
    # Checkout::Recipient. Os testes do destinatário montam o próprio.
    CHECKOUT_RECIPIENT_PARAMS = { name: "Cliente Teste", cpf: "529.982.247-25" }.freeze

    def checkout_recipient
      Checkout::Recipient.new(**CHECKOUT_RECIPIENT_PARAMS)
    end

    def checkout_recipient_params
      CHECKOUT_RECIPIENT_PARAMS
    end

    def capture_rails_events(name)
      events = []
      subscriber = Object.new
      subscriber.define_singleton_method(:emit) { |event| events << event }
      Rails.event.subscribe(subscriber) { |event| event[:name] == name }

      yield events
    ensure
      Rails.event.unsubscribe(subscriber) if subscriber
    end
  end
end
