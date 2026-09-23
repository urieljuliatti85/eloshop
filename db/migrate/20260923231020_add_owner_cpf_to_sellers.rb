class AddOwnerCpfToSellers < ActiveRecord::Migration[8.1]
  def change
    add_column :sellers, :owner_full_name, :string
    add_column :sellers, :cpf_ciphertext, :text
    add_column :sellers, :cpf_hash, :string
    add_index :sellers, :cpf_hash, unique: true, where: "cpf_hash IS NOT NULL"
  end
end
