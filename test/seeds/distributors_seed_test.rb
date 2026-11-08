require "test_helper"

class DistributorsSeedTest < ActiveSupport::TestCase
  SEED = Rails.root.join("db/seeds/distributors.rb")

  test "is additive and idempotent, with a preview that has no account or products" do
    existing_material = Material.find_or_create_by!(name: "Algodão")
    existing_material.update!(icon_type: :other)
    custom_icon_material = Material.find_or_create_by!(name: "Feltro")
    custom_icon_material.update!(icon_type: :clay)
    existing_technique = Technique.find_or_create_by!(name: "Crochê")
    existing_technique.update!(icon_type: :other)
    2.times { load SEED }

    preview = Seller.find_by!(slug: Seller::PREVIEW_DISTRIBUTOR_SLUG)
    assert preview.distributor?
    assert preview.showcased_at.present?
    assert_equal :pending, preview.status.to_sym
    assert_empty preview.users
    assert_empty preview.products
    assert_equal "yarn", existing_material.reload.icon_type
    assert_equal "clay", custom_icon_material.reload.icon_type
    assert_equal "yarn", existing_technique.reload.icon_type
    assert_equal DistributorCatalogSeed::MATERIALS.size, Material.where(name: DistributorCatalogSeed::MATERIALS.keys).count
    assert_equal DistributorCatalogSeed::TECHNIQUES.size, Technique.where(name: DistributorCatalogSeed::TECHNIQUES.keys).count
  end

  test "does not modify a non-distributor that already owns the preview slug" do
    seller = sellers(:pending)
    seller.update!(slug: Seller::PREVIEW_DISTRIBUTOR_SLUG)
    original_name = seller.name

    load SEED

    assert_equal original_name, seller.reload.name
    assert_not seller.distributor?
    assert_nil Seller.where(slug: Seller::PREVIEW_DISTRIBUTOR_SLUG).where.not(id: seller.id).first
  end
end
