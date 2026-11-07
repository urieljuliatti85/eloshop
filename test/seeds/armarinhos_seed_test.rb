require "test_helper"

class ArmarinhosSeedTest < ActiveSupport::TestCase
  SEED = Rails.root.join("db/seeds/armarinhos.rb")
  SELLER_SLUGS = %w[
    armarinho-fios-e-cores
    armarinho-tecidos-e-estampas
    armarinho-aviamentos-criativos
  ].freeze
  SUPPLY_SKUS = %w[
    SEED-FIO-ALGODAO-001 SEED-FIO-MALHA-001
    SEED-TRICOLINE-FLORAL-001 SEED-FELTRO-001
    SEED-FITA-GORGURAO-001 SEED-BOTOES-MADEIRA-001
  ].freeze

  test "creates local armarinhos and published supplies idempotently" do
    2.times { load SEED }

    sellers = Seller.where(slug: SELLER_SLUGS)
    supplies = Product.where(sku: SUPPLY_SKUS)

    assert_equal 3, sellers.count
    assert_equal 6, supplies.count
    assert supplies.all?(&:active?)
    assert_equal 3, User.where(email_address: %w[
      fios@armarinhos.eloshop.test
      tecidos@armarinhos.eloshop.test
      aviamentos@armarinhos.eloshop.test
    ]).count
    assert_equal 6, supplies.joins(:price_tiers).distinct.count
    assert_equal 6, supplies.joins(:materials).distinct.count
    assert_equal 6, supplies.joins(:techniques).distinct.count
  end

  test "is a no-op in production" do
    original_env = Rails.env
    Rails.env = "production"

    assert_no_difference [ "Seller.count", "Product.count", "Material.count", "Technique.count", "User.count" ] do
      load SEED
    end
  ensure
    Rails.env = original_env
  end
end
