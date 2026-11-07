# frozen_string_literal: true

require "rails_helper"

# Achado do QA (2026-11-07): `authenticate_by` levanta ArgumentError quando a
# senha não vem no POST, e cada porta de login respondia 500. Qualquer robô
# gerava erro à vontade e enchia o Sentry. Sem e-mail ou sem senha, cada porta
# volta ao próprio login com a mesma mensagem genérica.
RSpec.describe "Login without e-mail or password", type: :request do
  [
    [ "admin", :session_path, :new_session_path, :email_address ],
    [ "atelier", :seller_login_path, :seller_login_path, :email_address ],
    [ "distributor", :distributor_login_path, :distributor_login_path, :email_address ],
    [ "customer", :customer_session_path, :new_customer_session_path, :email ]
  ].each do |door, create_path, login_path, email_param|
    it "answers the #{door} door with the generic error, not a 500" do
      [ {}, { email_param => "alguem@example.com" }, { password: "password123" },
        { email_param => [ "a" ], password: { "x" => "y" } } ].each do |params|
        post send(create_path), params: params

        expect(response).to have_http_status(:redirect), "#{door} with #{params.keys.inspect} answered #{response.status}"
        expect(response).to redirect_to(send(login_path))
      end
    end
  end
end
