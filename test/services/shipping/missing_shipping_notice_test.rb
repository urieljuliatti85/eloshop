require "test_helper"

module Shipping
  class MissingShippingNoticeTest < ActiveSupport::TestCase
    setup do
      @seller = sellers(:approved)
      Product.where(seller: @seller).update_all(status: "draft")
    end

    def published(name, **attributes)
      Product.create!(seller: @seller, name: name, sku: "MSN-#{SecureRandom.hex(4)}", price_cents: 1000,
        stock_quantity: 1, currency: "BRL", status: "active", **attributes)
    end

    def notices
      Notification.where(recipient: @seller, kind: "shipping_setup_required")
    end

    test "notifies an atelier with published products still on the estimated shipping" do
      published("Sem frete A")
      published("Sem frete B")

      assert_equal 1, MissingShippingNotice.call

      notice = notices.sole
      assert_includes notice.body, "2 produtos publicados estão"
      assert_equal "/painel/products", notice.url
    end

    test "ignores products with seller-defined or free shipping, and drafts" do
      published("Com frete", fixed_shipping_cents: 2000, fixed_shipping_estimated_days: 5)
      published("Grátis", free_shipping: true)
      Product.create!(seller: @seller, name: "Rascunho", sku: "MSN-#{SecureRandom.hex(4)}", price_cents: 1000,
        stock_quantity: 1, currency: "BRL", status: "draft")

      assert_equal 0, MissingShippingNotice.call
      assert_empty notices
    end

    # Rodar a tarefa de novo não pode encher o sino com o mesmo aviso.
    test "does not repeat the notice while the previous one is unread" do
      published("Sem frete")

      MissingShippingNotice.call
      assert_equal 0, MissingShippingNotice.call
      assert_equal 1, notices.count

      notices.sole.mark_as_read!
      assert_equal 1, MissingShippingNotice.call
    end
  end
end
