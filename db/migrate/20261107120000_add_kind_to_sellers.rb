# Distribuidor de insumos é um `Seller` com outro tipo (ADR 007). Todo vendedor
# existente é ateliê: o default preenche as linhas atuais sem backfill à parte.
#
# O CPF passa a ser único por tipo, e não mais entre todos os vendedores: a
# artesã que abre uma distribuidora usa o próprio CPF. O antifraude do índice
# (ateliê suspenso não se recadastra como ateliê) continua dentro de cada tipo,
# e `Seller#suspend!` suspende o outro tipo do mesmo CPF.
#
# Compatível com a versão anterior rodando durante o deploy: ela não conhece
# `kind` (o default cobre os INSERTs dela), e o índice novo é mais permissivo
# que o antigo, então nada que ela grava passa a falhar.
#
# Rollback: só é viável enquanto nenhum CPF tiver os dois tipos. Depois disso,
# recriar o índice único global falha com PG::UniqueViolation (confirmado no QA
# de 2026-11-07); voltar exige antes decidir o que fazer com esses vendedores.
class AddKindToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :kind, :string, null: false, default: "atelier"
    add_check_constraint :sellers, "kind IN ('atelier', 'distributor')", name: "sellers_kind_check"

    # CNPJ é opcional (ADR 007); guardado só com dígitos.
    add_column :sellers, :cnpj, :string
    # Declaração pública do distribuidor: emite nota fiscal? Nula até ele
    # responder; a obrigatoriedade depende de consulta jurídica (ADR 007).
    add_column :sellers, :issues_invoices, :boolean

    remove_index :sellers, :cpf_hash, unique: true, where: "cpf_hash IS NOT NULL", name: "index_sellers_on_cpf_hash"
    add_index :sellers, %i[cpf_hash kind], unique: true, where: "cpf_hash IS NOT NULL", name: "index_sellers_on_cpf_hash_and_kind"
  end
end
