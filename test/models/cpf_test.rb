require "test_helper"

class CpfTest < ActiveSupport::TestCase
  test "accepts a CPF with valid check digits, with or without punctuation" do
    assert Cpf.valid?("52998224725")
    assert Cpf.valid?("529.982.247-25")
  end

  test "rejects wrong check digits, wrong length and repeated digits" do
    assert_not Cpf.valid?("52998224724")
    assert_not Cpf.valid?("5299822472")
    assert_not Cpf.valid?("529982247250")
    assert_not Cpf.valid?("11111111111")
    assert_not Cpf.valid?("")
    assert_not Cpf.valid?(nil)
  end

  test "formats progressively and leaves overlong input unmasked" do
    assert_equal "529.982.247-25", Cpf.format("52998224725")
    assert_equal "529.9", Cpf.format("5299")
    assert_equal "529982247250", Cpf.format("529982247250")
  end

  test "masks all but the last two digits" do
    assert_equal "***.***.***-25", Cpf.mask("529.982.247-25")
    assert_nil Cpf.mask(nil)
  end
end
