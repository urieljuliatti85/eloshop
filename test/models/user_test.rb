require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "defaults to the admin role" do
    user = User.new
    assert user.admin?
  end

  # A plataforma não pode ficar sem quem a administre: sem admin, o painel
  # fica inacessível e não há caminho de volta pela interface.
  test "refuses to destroy the last admin" do
    User.where.not(id: users(:one).id).destroy_all

    assert users(:one).last_admin?
    assert_not users(:one).destroy
    assert User.exists?(users(:one).id)
  end

  test "allows destroying an admin while another remains" do
    assert_not users(:one).last_admin?
    assert users(:one).destroy
  end

  # O vendedor não conta como administrador: removê-lo não pode ser barrado
  # por essa regra, e ele não segura a vaga do último admin.
  test "a seller is never the last admin" do
    assert_not users(:seller).last_admin?
  end

  # ADR 007: a porta da conta sai daqui, e um distribuidor nunca é tratado
  # como ateliê só por ter o papel `seller`.
  test "portal names the door of each kind of account" do
    assert_equal :admin, users(:one).portal
    assert_equal :atelier, users(:seller).portal

    distributor = Seller.create!(name: "Fios Atacado", owner_full_name: "Dona dos Fios", cpf: "52998224725", kind: "distributor")
    user = User.create!(email_address: "fios@example.com", password: "password123", role: :seller, seller: distributor)
    assert_equal :distributor, user.portal
  end
end
