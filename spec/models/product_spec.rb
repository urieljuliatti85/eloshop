# frozen_string_literal: true

require "rails_helper"
require "stringio"

RSpec.describe Product, type: :model do
  before do
    clear_product_data!
  end

  let(:valid_attributes) do
    {
      seller: approved_seller,
      name: "Vaso artesanal azul",
      sku: "VASO-ARTE-001",
      price_cents: 8_990,
      stock_quantity: 3,
      currency: "BRL",
      # Medidas: `publish!` as exige, porque o frete real cotiza por peso.
      weight_grams: 500,
      length_cm: 20,
      width_cm: 15,
      height_cm: 10
    }
  end

  describe "validations" do
    it "requires a name" do
      product = described_class.new(valid_attributes.except(:name).merge(name: nil))

      expect(product).not_to be_valid
      expect(product.errors[:name]).to include("can't be blank")
    end

    it "requires a sku" do
      product = described_class.new(valid_attributes.except(:sku).merge(sku: nil))

      expect(product).not_to be_valid
      expect(product.errors[:sku]).to include("can't be blank")
    end

    it "rejects duplicate slug" do
      described_class.create!(valid_attributes.merge(slug: "vaso-artesanal-azul", sku: "UNICO-001"))
      duplicate = described_class.new(valid_attributes.merge(slug: "vaso-artesanal-azul", sku: "OUTRO-SKU"))

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include("has already been taken")
    end

    it "rejects duplicate sku" do
      described_class.create!(valid_attributes.merge(sku: "UNICO-001", slug: "vaso-um"))
      duplicate = described_class.new(valid_attributes.merge(sku: "UNICO-001", slug: "vaso-dois"))

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:sku]).to include("has already been taken")
    end

    it "rejects negative price_cents" do
      product = described_class.new(valid_attributes.merge(price_cents: -1, slug: nil, sku: "NEG-PRICE"))

      expect(product).not_to be_valid
      expect(product.errors[:price_cents]).to include("must be greater than or equal to 0")
    end

    it "rejects negative stock_quantity" do
      product = described_class.new(valid_attributes.merge(stock_quantity: -1, slug: nil, sku: "NEG-STOCK"))

      expect(product).not_to be_valid
      expect(product.errors[:stock_quantity]).to include("must be greater than or equal to 0")
    end

    it "assigns slug from name when slug is blank" do
      product = described_class.new(name: "Tapete de Fibra Natural", sku: "TAPETE-001", price_cents: 1_000, stock_quantity: 1, currency: "BRL")

      product.valid?

      expect(product.slug).to eq("tapete-de-fibra-natural")
    end

    it "does not overwrite an explicitly assigned slug" do
      product = described_class.new(name: "Tapete de Fibra Natural", slug: "meu-slug-personalizado", sku: "TAPETE-002", price_cents: 1_000, stock_quantity: 1, currency: "BRL")

      product.valid?

      expect(product.slug).to eq("meu-slug-personalizado")
    end

    it "rejects a disallowed main image content type" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-accepted", sku: "IMG-ACCEPTED-1"))
      product.main_image.attach(io: StringIO.new("plain text"), filename: "doc.txt", content_type: "text/plain")

      expect(product).not_to be_valid
      expect(product.errors[:main_image]).to include("deve ser um arquivo PNG, JPEG ou WEBP")
    end

    it "rejects a main image larger than 5MB" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-large", sku: "IMG-LARGE-1"))
      large_content = "a" * (described_class::MAIN_IMAGE_MAX_BYTES + 1)
      product.main_image.attach(io: StringIO.new(large_content), filename: "big.png", content_type: "image/png")

      expect(product).not_to be_valid
      expect(product.errors[:main_image]).to include("deve ter no máximo 5MB")
    end

    it "accepts a valid main image" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-valid-image", sku: "IMG-VALID-1"))
      product.main_image.attach(io: StringIO.new("fake image bytes"), filename: "photo.png", content_type: "image/png")

      expect(product).to be_valid
    end

    it "rejects gallery images with disallowed content types" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-gallery", sku: "IMG-GALLERY-1"))
      product.images.attach(io: StringIO.new("plain text"), filename: "doc.txt", content_type: "text/plain")

      expect(product).not_to be_valid
      expect(product.errors[:images]).to include("deve conter apenas arquivos PNG, JPEG ou WEBP")
    end

    it "rejects gallery images larger than 5MB" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-gallery-large", sku: "IMG-GALLERY-2"))
      large_content = "a" * (described_class::MAIN_IMAGE_MAX_BYTES + 1)
      product.images.attach(io: StringIO.new(large_content), filename: "big.png", content_type: "image/png")

      expect(product).not_to be_valid
      expect(product.errors[:images]).to include("cada imagem deve ter no máximo 5MB")
    end

    it "rejects more than the maximum number of gallery images" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-muitos", sku: "IMG-GALLERY-3"))

      (described_class::IMAGES_MAX_COUNT + 1).times do |index|
        product.images.attach(io: StringIO.new("fake image bytes"), filename: "photo#{index}.png", content_type: "image/png")
      end

      expect(product).not_to be_valid
      expect(product.errors[:images]).to include("não pode ter mais de #{described_class::IMAGES_MAX_COUNT} imagens")
    end

    it "accepts valid gallery images" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-gallery-ok", sku: "IMG-GALLERY-4"))
      product.images.attach(io: StringIO.new("fake image bytes"), filename: "photo.png", content_type: "image/png")

      expect(product).to be_valid
    end
  end

  describe "status transitions" do
    it "publishes a draft product to active" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-draft", sku: "STATUS-001", status: :draft))

      product.publish!

      expect(product).to be_active
    end

    it "raises for an invalid transition from discontinued to active" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-discontinued", sku: "STATUS-002", status: :active))
      product.discontinue!

      expect { product.publish! }.to raise_error(described_class::InvalidStatusTransition)
    end

    it "unpublishes an active product to draft" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-active", sku: "STATUS-003", status: :active))

      product.unpublish!

      expect(product).to be_draft
    end

    it "raises for invalid discontinue from draft" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-draft-2", sku: "STATUS-004", status: :draft))

      expect { product.discontinue! }.to raise_error(described_class::InvalidStatusTransition)
    end

    it "keeps discontinued as a terminal state" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-terminal", sku: "STATUS-005", status: :active))
      product.discontinue!

      expect { product.publish! }.to raise_error(described_class::InvalidStatusTransition)
      expect { product.unpublish! }.to raise_error(described_class::InvalidStatusTransition)
    end

    it "allows a standard product to return to active after sold_out" do
      product = described_class.create!(valid_attributes.merge(slug: "vaso-restock", sku: "STATUS-006", status: :active, stock_quantity: 1))
      product.update!(status: "sold_out")

      product.publish!

      expect(product).to be_active
    end
  end

  describe "availability" do
    it "is purchaseable only when active and in stock" do
      active = described_class.create!(valid_attributes.merge(slug: "vaso-disponivel", sku: "AVAIL-001", status: :active, stock_quantity: 2))
      inactive = described_class.create!(valid_attributes.merge(slug: "vaso-rascunho", sku: "AVAIL-002", status: :draft, stock_quantity: 2))

      expect(active).to be_available_for_purchase
      expect(inactive).not_to be_available_for_purchase

      active.update!(stock_quantity: 0)
      expect(active).not_to be_available_for_purchase
    end

    it "supports one of a kind products with stock up to 1" do
      product = described_class.new(valid_attributes.merge(slug: "peca-unica-1", sku: "UNICA-001", availability_type: "one_of_a_kind", stock_quantity: 2))

      expect(product).not_to be_valid
      expect(product.errors[:stock_quantity]).to include("must be less than or equal to 1")

      valid = described_class.new(valid_attributes.merge(slug: "peca-unica-2", sku: "UNICA-002", availability_type: "one_of_a_kind", stock_quantity: 1))
      expect(valid).to be_valid
    end

    it "does not allow one_of_a_kind to return to active after sold out" do
      product = described_class.create!(valid_attributes.merge(slug: "peca-unica-3", sku: "UNICA-003", availability_type: "one_of_a_kind", stock_quantity: 1))
      product.update!(status: "sold_out")

      expect { product.publish! }.to raise_error(described_class::InvalidStatusTransition)
    end

    it "treats made_to_order as purchasable regardless of stock" do
      product = described_class.new(valid_attributes.merge(slug: "encomenda-1", sku: "ENCOMENDA-003", status: :active, availability_type: "made_to_order", production_time_min_days: 7, production_time_max_days: 10, stock_quantity: 0))

      expect(product).to be_available_for_purchase
    end

    it "requires production time range for made_to_order products" do
      product = described_class.new(valid_attributes.merge(slug: "encomenda-2", sku: "ENCOMENDA-001", availability_type: "made_to_order"))

      expect(product).not_to be_valid
      expect(product.errors[:production_time_min_days]).to include("can't be blank")
      expect(product.errors[:production_time_max_days]).to include("can't be blank")
    end

    it "rejects a max lead time smaller than the minimum" do
      product = described_class.new(valid_attributes.merge(slug: "encomenda-3", sku: "ENCOMENDA-002", availability_type: "made_to_order", production_time_min_days: 10, production_time_max_days: 5))

      expect(product).not_to be_valid
      expect(product.errors[:production_time_max_days]).to include("deve ser maior ou igual ao prazo mínimo")
    end
  end

  describe "metadata helpers" do
    it "returns the stable id in to_param" do
      product = described_class.create!(valid_attributes.merge(slug: "slug-para-param", sku: "PARAM-001"))

      expect(product.to_param).to eq(product.id.to_s)
    end

    it "formats production time range" do
      product = described_class.new(availability_type: "made_to_order", production_time_min_days: 7, production_time_max_days: 10)

      expect(product.production_time_range).to eq("7 a 10 dias úteis")
    end

    it "returns nil for non made to order products" do
      product = described_class.create!(valid_attributes.merge(slug: "prod-foo", sku: "PROD-FOO-1"))

      expect(product.production_time_range).to be_nil
    end
  end

  describe "variant and gallery behavior" do
    it "detects whether product has variants" do
      product = described_class.create!(valid_attributes.merge(slug: "sem-variantes", sku: "VAR-001", availability_type: "standard"))
      variant = ProductVariant.create!(product: product, sku: "VAR-001-1", price_cents: 9_500, stock_quantity: 2, active: true, color: "Azul")

      expect(product.has_variants?).to be(true)
      expect(product.product_variants).to include(variant)
    end

    it "uses the variant availability when variants are present" do
      product = described_class.create!(valid_attributes.merge(slug: "com-variantes", sku: "VAR-002", stock_quantity: 0, status: :active, availability_type: "standard"))
      ProductVariant.create!(product: product, sku: "VAR-002-1", price_cents: 9_500, stock_quantity: 2, active: true, color: "Azul")
      ProductVariant.create!(product: product, sku: "VAR-002-2", price_cents: 10_500, stock_quantity: 0, active: true, color: "Verde")

      expect(product).to be_available_for_purchase

      product.product_variants.update_all(active: false)
      expect(product.reload).not_to be_available_for_purchase
    end

    it "prevents changes to availability type while product has variants" do
      product = described_class.create!(valid_attributes.merge(slug: "variante-locked", sku: "VAR-003", availability_type: "standard"))
      ProductVariant.create!(product: product, sku: "VAR-003-1", price_cents: 9_500, stock_quantity: 2, active: true, color: "Azul")

      product.availability_type = "made_to_order"

      expect(product).not_to be_valid
      expect(product.errors[:availability_type]).to include("não pode ser alterado enquanto o produto tiver variantes cadastradas")
    end

    it "puts the main image before the remainder of gallery images" do
      product = described_class.create!(valid_attributes.merge(slug: "galeria-ordem", sku: "GAL-001"))
      product.main_image.attach(io: StringIO.new("cover"), filename: "cover.png", content_type: "image/png")
      product.images.attach(io: StringIO.new("extra"), filename: "extra.png", content_type: "image/png")

      photos = product.gallery_images

      expect(photos.size).to eq(2)
      expect(photos.first.filename.to_s).to eq("cover.png")
      expect(photos.second.filename.to_s).to eq("extra.png")
    end
  end

  describe "related products and reviews" do
    it "excludes itself and non-active products from related products" do
      active = described_class.create!(valid_attributes.merge(slug: "produto-relacionado-1", sku: "REL-001", status: :active))
      draft = described_class.create!(valid_attributes.merge(slug: "produto-relacionado-2", sku: "REL-002", status: :draft))

      related = active.related_products

      expect(related).not_to include(active)
      expect(related).not_to include(draft)
      expect(related.all?(&:active?)).to be(true)
    end

    it "respects the limit of related products" do
      product = described_class.create!(valid_attributes.merge(slug: "produto-limitado", sku: "REL-003", status: :active))

      expect(product.related_products(limit: 1).size).to be <= 1
    end

    it "counts only approved reviews for average rating" do
      product = described_class.create!(valid_attributes.merge(slug: "produto-avaliacao", sku: "REL-004", status: :active))
      product.reviews.create!(customer: Customer.create!(name: "Cliente 1", email: "cliente1#{SecureRandom.hex(4)}@example.com", password: "password123"), rating: 5, comment: "Ótimo", status: "approved")
      product.reviews.create!(customer: Customer.create!(name: "Cliente 2", email: "cliente2#{SecureRandom.hex(4)}@example.com", password: "password123"), rating: 3, comment: "Pendente")

      expect(product.average_rating).to eq(5.0)
      expect(product.reviews_count).to eq(1)
    end

    it "returns nil when there are no approved reviews" do
      product = described_class.create!(valid_attributes.merge(slug: "produto-sem-avaliacao", sku: "REL-005", status: :active))

      expect(product.average_rating).to be_nil
      expect(product.reviews_count).to eq(0)
    end
  end
end
