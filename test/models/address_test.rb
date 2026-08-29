require "test_helper"

class AddressTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    address = Address.new(
      customer: customers(:one),
      street: "Rua Nova",
      number: "10",
      neighborhood: "Bairro",
      city: "Cidade",
      state: "SP",
      zip_code: "00000-000"
    )
    assert address.valid?
  end

  test "valid without complement" do
    address = Address.new(
      customer: customers(:one),
      street: "Rua Nova",
      number: "10",
      neighborhood: "Bairro",
      city: "Cidade",
      state: "SP",
      zip_code: "00000-000",
      complement: nil
    )
    assert address.valid?
  end

  test "invalid without required fields" do
    address = Address.new(customer: customers(:one))
    assert_not address.valid?
    %i[street number neighborhood city state zip_code].each do |field|
      assert_includes address.errors[field], "can't be blank"
    end
  end
end
