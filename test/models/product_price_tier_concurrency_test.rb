require "test_helper"

# Concorrência real (duas conexões, sem a transação do teste envolvendo
# tudo): duas faixas salvas ao mesmo tempo, cada uma coerente sozinha mas
# contraditórias juntas, não podem passar as duas. A trava na linha do produto
# (ProductPriceTier#coherent_with_the_other_tiers) faz a segunda esperar a
# primeira e conferir o conjunto já com ela.
#
# Para a corrida acontecer de verdade, cada save, depois de ler as outras
# faixas, espera até 1 s a outra também ler. Sem a trava as duas leem o estado
# antigo e passam; com ela a segunda só lê depois do commit da primeira (a
# espera da primeira vence pelo tempo). Sem esse encontro forçado as threads
# não se cruzavam e o teste passava até sem a trava.
class ProductPriceTierConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  module ReadRendezvous
    mattr_accessor :latch

    private

    def sibling_tiers_as_they_will_be
      super.tap do
        ReadRendezvous.latch&.count_down
        ReadRendezvous.latch&.wait(1)
      end
    end
  end
  ProductPriceTier.prepend(ReadRendezvous)

  setup do
    @distributor = Seller.create!(name: "Fios Corrida #{SecureRandom.hex(3)}", owner_full_name: "Dona dos Fios",
      cpf: "52998224725", kind: "distributor", status: :approved, approved_at: 1.day.ago)
    @supply = Product.create!(seller: @distributor, name: "Fio corrida", price_cents: 2_500, stock_quantity: 100, status: :active)
  end

  teardown do
    ProductPriceTier.where(product_id: @supply.id).delete_all
    PaperTrail::Version.where(item_type: "Product", item_id: @supply.id).delete_all if defined?(PaperTrail::Version)
    Product.where(id: @supply.id).delete_all
    PaperTrail::Version.where(item_type: "Seller", item_id: @distributor.id).delete_all if defined?(PaperTrail::Version)
    Seller.where(id: @distributor.id).delete_all
  end

  test "two contradicting tiers saved at the same time do not both pass" do
    # 10 unidades com 20% e 50 unidades com 5%: cada uma sozinha é válida.
    attempts = [ [ 10, 2_000 ], [ 50, 500 ] ]
    ReadRendezvous.latch = Concurrent::CountDownLatch.new(2)
    gate = Queue.new
    threads = attempts.map do |quantity, discount|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          ProductPriceTier.new(product: Product.find(@supply.id), min_quantity: quantity, discount_bps: discount).save
        end
      end
    end
    2.times { gate << true }
    results = threads.map(&:value)
    ReadRendezvous.latch = nil

    assert_equal 1, results.count(true), "só uma das duas faixas contraditórias pode ser gravada"
    tiers = ProductPriceTier.where(product_id: @supply.id).order(:min_quantity).pluck(:discount_bps)
    assert_equal tiers.sort, tiers, "os descontos gravados continuam crescentes"
  end
end
