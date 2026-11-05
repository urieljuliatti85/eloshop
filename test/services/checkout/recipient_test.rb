require "test_helper"

module Checkout
  class RecipientTest < ActiveSupport::TestCase
    test "requires name and a valid CPF for delivery" do
      recipient = Recipient.new(name: "  Ana   Souza ", cpf: "529.982.247-25")

      assert recipient.valid_for?(delivery: true)
      assert_equal "Ana Souza", recipient.name
      assert_equal "52998224725", recipient.cpf
    end

    test "refuses delivery without CPF, but accepts local pickup without it" do
      recipient = Recipient.new(name: "Ana Souza")

      assert_not recipient.valid_for?(delivery: true)
      assert_includes recipient.errors[:cpf], "Informe o CPF de quem vai receber: a transportadora exige na etiqueta"
      assert recipient.valid_for?(delivery: false)
    end

    test "refuses an invalid CPF even on local pickup" do
      recipient = Recipient.new(name: "Ana Souza", cpf: "529.982.247-24")

      assert_not recipient.valid_for?(delivery: false)
      assert_includes recipient.errors[:cpf], "CPF inválido: confira os 11 números"
    end

    test "requires a name" do
      recipient = Recipient.new(name: "   ", cpf: "52998224725")

      assert_not recipient.valid_for?(delivery: true)
      assert_includes recipient.errors[:name], "Informe o nome de quem vai receber"
    end

    test "keeps only the phone digits and drops the country code" do
      assert_equal "27999991234", Recipient.new(phone: "+55 (27) 99999-1234").phone
      assert_equal "2733331234", Recipient.new(phone: "(27) 3333-1234").phone
      assert_nil Recipient.new(phone: "  ").phone
    end

    test "phone is optional but must have area code and number when given" do
      assert Recipient.new(name: "Ana Souza", cpf: "52998224725", phone: "(27) 99999-1234").valid_for?(delivery: true)

      recipient = Recipient.new(name: "Ana Souza", cpf: "52998224725", phone: "99999-1234")
      assert_not recipient.valid_for?(delivery: true)
      assert_includes recipient.errors[:phone], "Telefone inválido: use DDD e número, como (27) 99999-9999"
    end

    test "anything other than the expected params becomes an empty recipient" do
      assert_nil Recipient.from_params("Ana").name
      assert_nil Recipient.from_params(nil).name

      params = ActionController::Parameters.new(name: "Ana Souza", cpf: "52998224725", admin: "1")
      assert_equal "Ana Souza", Recipient.from_params(params).name
    end
  end
end
