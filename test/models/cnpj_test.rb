require "test_helper"

class CnpjTest < ActiveSupport::TestCase
  test "validates a numeric CNPJ by its check digits" do
    assert Cnpj.valid?("11.222.333/0001-81")
    assert Cnpj.valid?("11222333000181")
    assert_not Cnpj.valid?("11.222.333/0001-82")
  end

  test "validates the alphanumeric CNPJ issued since July 2026" do
    assert Cnpj.valid?("12.ABC.345/01DE-35")
    assert Cnpj.valid?("12abc34501de35")
    assert_not Cnpj.valid?("12.ABC.345/01DE-36")
  end

  test "rejects the wrong length, letters in the check digits and repeated characters" do
    assert_not Cnpj.valid?("1122233300018")
    assert_not Cnpj.valid?("12ABC34501DEAB")
    assert_not Cnpj.valid?("00000000000000")
    assert_not Cnpj.valid?(nil)
  end

  test "normalizes to uppercase letters and digits and formats 14 characters" do
    assert_equal "12ABC34501DE35", Cnpj.normalize("12.abc.345/01de-35")
    assert_equal "11.222.333/0001-81", Cnpj.format("11222333000181")
    assert_equal "1122", Cnpj.format("11.22")
  end
end
