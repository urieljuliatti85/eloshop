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

  test "usa a foto real do catálogo quando existe arquivo para o SKU" do
    Rails.application.load_seed

    com_foto = Product.find_by!(sku: "CESTO-VIME-001")
    assert_equal "image/jpeg", com_foto.main_image.blob.content_type,
                 "deveria anexar a foto de db/seeds/images"

    sem_foto = Product.find_by!(sku: "VASO-AZUL-001")
    assert_equal "image/png", sem_foto.main_image.blob.content_type,
                 "sem foto para o SKU, deve cair no gradiente"
  end

  # O seed roda a cada boot: trocar uma imagem enviada pelo admin seria
  # destrutivo e silencioso.
  test "não sobrescreve imagem que não foi gerada pelo seed" do
    Rails.application.load_seed
    product = Product.find_by!(sku: "VASO-AZUL-001")

    product.main_image.purge
    product.reload
    product.main_image.attach(
      io: file_fixture("sample.png").open,
      filename: "foto-do-artesao.png",
      content_type: "image/png"
    )

    Rails.application.load_seed

    assert_equal "foto-do-artesao.png", product.reload.main_image.blob.filename.to_s
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
