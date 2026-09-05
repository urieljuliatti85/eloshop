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
end
