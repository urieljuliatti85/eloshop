ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Paralelização por fork trava de forma reproduzível neste ambiente assim
    # que a suíte passa de 50 testes (o processo forkado nunca retoma após o
    # check de schema do Active Record). Desativada até a causa raiz ser
    # investigada — ver nota na Fase 3 do ROADMAP.md.
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
