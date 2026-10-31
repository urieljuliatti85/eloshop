require "test_helper"

# O projeto não tem a gem rails-i18n: sem estas chaves, as validações padrão
# do Rails e os nomes dos atributos aparecem em inglês no cadastro de produto.
class ErrorMessagesTranslationTest < ActiveSupport::TestCase
  test "every default Rails error message has a pt-BR translation" do
    english = I18n.t("errors.messages", locale: :en)
    missing = english.keys.reject { |key| I18n.exists?("errors.messages.#{key}", :"pt-BR") }

    assert_empty missing, "faltam traduções em pt-BR para errors.messages: #{missing.join(', ')}"
  end

  test "product validation errors are fully in Portuguese, attribute names included" do
    product = Product.new(price_cents: -1, stock_quantity: -1, weight_grams: 0, fixed_shipping_cents: 0, availability_type: "made_to_order")
    product.valid?

    messages = product.errors.full_messages

    assert_includes messages, "Nome não pode ficar em branco"
    assert_includes messages, "Preço deve ser maior ou igual a 0"
    assert_includes messages, "Estoque deve ser maior ou igual a 0"
    assert_includes messages, "Peso deve ser maior que 0"
    assert_includes messages, "Produção mínima não pode ficar em branco"
    assert_includes messages, "Artesão é obrigatório(a)"
    assert_empty messages.grep(/can't|must|is not|has already|Weight|Price cents|Stock quantity|Production time/i)
  end

  test "image and variant errors use Portuguese attribute names" do
    product = products(:one)
    (Product::IMAGES_MAX_COUNT + 1).times do |i|
      product.images.attach(io: StringIO.new("fake image bytes"), filename: "photo#{i}.png", content_type: "image/png")
    end
    product.valid?
    variant = ProductVariant.new.tap(&:valid?)

    assert_includes product.errors.full_messages, "Galeria de imagens não pode ter mais de #{Product::IMAGES_MAX_COUNT} imagens"
    assert_includes variant.errors.full_messages, "SKU não pode ficar em branco"
    assert_includes variant.errors.full_messages, "Produto é obrigatório(a)"
  end

  test "seller registration errors are in Portuguese" do
    seller = Seller.new.tap { |record| record.valid?(:create) }
    customer = Customer.new.tap(&:valid?)

    assert_includes seller.errors.full_messages, "Nome do ateliê não pode ficar em branco"
    assert_includes seller.errors.full_messages, "Nome completo do responsável não pode ficar em branco"
    assert_includes seller.errors.full_messages, "CPF não pode ficar em branco"
    assert_includes customer.errors.full_messages, "Nome não pode ficar em branco"
    assert_includes customer.errors.full_messages, "Senha não pode ficar em branco"
  end

  # Modelos com formulário: um atributo validado sem tradução vira "Owner full
  # name não pode ficar em branco" na tela.
  FORM_MODELS = %w[
    User Customer Address Seller Category Material Tag Technique Coupon Review SellerReport
    WishlistItem MercadoPagoTestAccount CartItem Product ProductVariant PersonalizationOption OrderMessage
  ].freeze

  test "every validated attribute of a form model has a pt-BR name" do
    missing = FORM_MODELS.flat_map do |name|
      model = name.constantize
      scope = model < ActiveRecord::Base ? "activerecord" : "activemodel"
      model.validators.flat_map(&:attributes).uniq
        .reject { |attribute| I18n.exists?("#{scope}.attributes.#{model.model_name.i18n_key}.#{attribute}", :"pt-BR") }
        .map { |attribute| "#{name}##{attribute}" }
    end

    assert_empty missing, "atributos validados sem nome em pt-BR: #{missing.join(', ')}"
  end
end
