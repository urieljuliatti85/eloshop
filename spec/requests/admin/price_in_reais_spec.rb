# frozen_string_literal: true

require "rails_helper"

# O formulário do admin passou a receber preço em reais ("40,00") e converter
# para centavos, que continua sendo a unidade do banco.
RSpec.describe "Price entered in reais", type: :request do
  let(:user) { User.create!(email_address: "preco@eloshop.test", password: "password123") }

  before { sign_in_as(user) }

  def product_params(price)
    { product: { seller_id: approved_seller.id, name: "Peça de teste", description: "Descrição",
                 price: price, currency: "BRL", sku: "PRECO-#{SecureRandom.hex(4)}", stock_quantity: 1 } }
  end

  it "stores 40,00 as 4000 cents" do
    post admin_products_path, params: product_params("40,00")

    expect(Product.last.price_cents).to eq(4_000)
  end

  it "accepts a dot as decimal separator" do
    post admin_products_path, params: product_params("40.00")

    expect(Product.last.price_cents).to eq(4_000)
  end

  it "accepts the currency symbol and thousand separator" do
    post admin_products_path, params: product_params("R$ 1.299,90")

    expect(Product.last.price_cents).to eq(129_990)
  end

  # O caminho que motivou o BigDecimal: em Float, (0.29 * 100).round dá 28.
  it "converts cents without floating point drift" do
    post admin_products_path, params: product_params("0,29")

    expect(Product.last.price_cents).to eq(29)
  end

  it "shows the stored price back in the edit form" do
    post admin_products_path, params: product_params("89,90")

    get edit_admin_product_path(Product.last)

    expect(response.body).to include('value="89,90"')
  end
end
