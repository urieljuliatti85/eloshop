# frozen_string_literal: true

require "rails_helper"

# O topo dizia "Sair" sem dizer de quem — quem está logado não tinha
# confirmação de qual conta está usando.
RSpec.describe "Header identity", type: :request do
  let(:customer) { Customer.create!(name: "Maria Oliveira", email: "maria-topo@eloshop.test", password: "password123") }

  def sign_in_customer
    post customer_session_path, params: { email: customer.email, password: "password123" }
  end

  it "shows the first name of the signed-in customer" do
    sign_in_customer

    get root_path

    expect(response.body).to include("Maria")
  end

  it "offers the account destinations in the dropdown" do
    sign_in_customer

    get root_path

    expect(response.body).to include("Meus pedidos")
    expect(response.body).to include(orders_path)
    expect(response.body).to include(wishlist_path)
    expect(response.body).to include("Sair da conta")
  end

  it "shows the full name and email inside the panel" do
    sign_in_customer

    get root_path

    expect(response.body).to include("Maria Oliveira")
    expect(response.body).to include(customer.email)
  end

  # Casar contra o nome aqui seria frágil: o catálogo da home pode conter uma
  # artesã chamada Maria sem que nada esteja errado. O marcador é o menu de
  # conta em si, que só existe no ramo autenticado.
  it "shows nothing about identity to a visitor" do
    get root_path

    expect(response.body).not_to include("account-menu")
    expect(response.body).not_to include(customer.email)
    expect(response.body).to include("Entrar")
  end

  # O nome sai da sessão, nunca de parâmetro: trocar o e-mail na URL não
  # muda quem o topo diz que está logado.
  it "ignores an email passed as a parameter" do
    other = Customer.create!(name: "Joana Impostora", email: "joana-topo@eloshop.test", password: "password123")
    sign_in_customer

    get root_path, params: { email: other.email }

    expect(response.body).to include(customer.email)
    expect(response.body).not_to include(other.email)
  end
end
