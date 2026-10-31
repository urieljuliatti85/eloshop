require "test_helper"

# `db/seeds.rb` é o seed de desenvolvimento (catálogo de exemplo, vendedor
# "EloShop" e contas de senha conhecida). O entrypoint de produção não o chama
# e, mesmo que alguém rode `db:seed` lá (o `db:prepare` o faz na criação de um
# banco novo), ele precisa ser um no-op: produto, vendedor ou senha de exemplo
# em produção seriam um problema real.
class DevelopmentSeedTest < ActiveSupport::TestCase
  SEED = Rails.root.join("db/seeds.rb")

  test "does nothing in production" do
    original_env = Rails.env
    Rails.env = "production"

    assert_no_difference [ "Seller.count", "Product.count", "Category.count", "User.count", "Customer.count" ] do
      load SEED
    end
  ensure
    Rails.env = original_env
  end

  test "does not load the production category seed" do
    assert_no_match(/^\s*(load|require)\b.*categories/, File.read(SEED))
  end
end
