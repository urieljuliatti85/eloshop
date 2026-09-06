class AddMercadoPagoTestAccountToSellers < ActiveRecord::Migration[8.1]
  # `live_mode`, que vinha do token, não distingue conta de teste de conta
  # real: o Mercado Pago devolve `live_mode: true` também para TESTUSER,
  # porque do lado deles a conta transaciona de verdade. Quem distingue é a
  # tag `test_user` em /users/me.
  #
  # Nullable de propósito: conexões feitas antes desta coluna existirem não
  # têm a informação, e `false` afirmaria que são reais — o que é justamente
  # o erro que esta coluna vem corrigir.
  def change
    add_column :sellers, :mercado_pago_test_account, :boolean
  end
end
