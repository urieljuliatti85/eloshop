require "test_helper"

# Regressão de um bug que quebrou todas as imagens de produto em produção: os
# anexos foram criados enquanto o app ainda gravava no filesystem efêmero do
# container, antes do volume persistente. O Postgres guardou os registros de
# blob/attachment e o volume ficou vazio, então toda imagem respondia 404.
#
# O seed checava apenas `attached?` para decidir se anexava, então pulava
# exatamente esse caso: o estado quebrado se reaplicava a cada boot em vez de
# se curar. Ver db/seeds.rb.
class SeedsTest < ActiveSupport::TestCase
  test "reanexa imagem cujo arquivo sumiu do disco, sem duplicar anexo" do
    Rails.application.load_seed
    product = seeded_product

    assert product.main_image.attached?, "o seed deveria anexar a capa"
    assert_equal 1, product.images.count

    blob_before = product.main_image.blob
    delete_stored_file(blob_before)

    refute file_present?(blob_before), "pré-condição: o arquivo precisa estar ausente"

    Rails.application.load_seed
    product.reload

    assert product.main_image.attached?, "a capa deveria continuar anexada"
    assert file_present?(product.main_image.blob), "o arquivo deveria ter sido reanexado"
    assert_equal 1, product.images.count, "curar não pode duplicar a galeria"
  end

  test "não reanexa quando o arquivo está presente" do
    Rails.application.load_seed
    blob_id = seeded_product.main_image.blob.id

    Rails.application.load_seed

    assert_equal blob_id, seeded_product.main_image.blob.id,
                 "um seed repetido com arquivo íntegro não deve gerar blob novo"
  end

  private

  def seeded_product
    Product.find_by!(sku: "VASO-AZUL-001")
  end

  def file_present?(blob)
    blob.service.exist?(blob.key)
  end

  def delete_stored_file(blob)
    blob.service.delete(blob.key)
  end
end
