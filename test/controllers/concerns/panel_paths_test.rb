require "test_helper"

# PanelPaths (revisão de arquitetura de 2026-11-07): as telas que os dois
# painéis compartilham pedem o caminho pelo tipo do vendedor, e o ateliê
# continua exatamente nos mesmos endereços de antes.
class PanelPathsTest < ActiveSupport::TestCase
  setup do
    @controller = ApplicationController.new
    @controller.request = ActionDispatch::TestRequest.create
    @atelier = sellers(:approved)
    @distributor = Seller.create!(name: "Fios Caminhos", owner_full_name: "Dona dos Fios", cpf: "52998224725", kind: "distributor")
  end

  def panel_path(*args, **options)
    @controller.send(:panel_path, *args, **options)
  end

  test "an atelier keeps the /painel paths it always had" do
    assert_equal "/painel", panel_path(:root, seller: @atelier)
    assert_equal "/painel/primeiros-passos/endereco", panel_path(:getting_started, etapa: "endereco", seller: @atelier)
    assert_equal "/painel?etapa=chave-pix", panel_path(:root, etapa: "chave-pix", seller: @atelier)
    assert_equal "/painel/atelie/edit", panel_path(:edit_atelier, seller: @atelier)
    assert_equal "/painel/chave-pix", panel_path(:pix_key_confirmation, seller: @atelier)
    assert_equal "/painel/notifications/7/mark_as_read", panel_path(:mark_as_read_notification, 7, seller: @atelier)
  end

  test "a distributor gets the /atacado paths, and a screen its panel lacks fails loudly" do
    assert_equal "/atacado/painel", panel_path(:root, seller: @distributor)
    assert_equal "/atacado/painel/primeiros-passos/endereco", panel_path(:getting_started, etapa: "endereco", seller: @distributor)
    assert_equal "/atacado/painel/dados", panel_path(:atelier, seller: @distributor), "Dados do ateliê viram Dados da distribuidora"
    assert_equal "/atacado/painel/dados/edit", panel_path(:edit_atelier, seller: @distributor)
    assert_equal "/atacado/painel/dados/cep/01310100", panel_path(:atelier_postal_code, cep: "01310100", seller: @distributor)
    assert_equal "/atacado/painel/avisos/7/mark_as_read", panel_path(:mark_as_read_notification, 7, seller: @distributor)
    # O catálogo do distribuidor chega no PR B da Fase 26: até lá, erro alto.
    assert_raises(NoMethodError) { panel_path(:products, seller: @distributor) }
  end

  test "seller_panel_path_for is the root of each panel" do
    assert_equal "/painel", @controller.send(:seller_panel_path_for, @atelier)
    assert_equal "/atacado/painel", @controller.send(:seller_panel_path_for, @distributor)
  end
end
