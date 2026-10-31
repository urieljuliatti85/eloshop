# frozen_string_literal: true

require "rails_helper"

# Atrás da Railway o `remote_ip` é o do proxy interno e muda a cada requisição;
# o IP do visitante vem em `X-Real-IP`. Sem isso, nenhum `rate_limit` limita.
RSpec.describe "IP do cliente atrás do proxy da Railway", type: :request do
  def post_contact(ip)
    post contact_path,
         params: { contact_message: { name: "Bot", email: "bot@example.com", message: "x" } },
         headers: { "X-Real-IP" => ip },
         env: { "REMOTE_ADDR" => "100.64.0.#{rand(2..250)}" }
  end

  it "usa o X-Real-IP como remote_ip" do
    get "/up", headers: { "X-Real-IP" => "203.0.113.9" }

    expect(request.remote_ip).to eq("203.0.113.9")
  end

  it "cai no comportamento padrão sem o cabeçalho ou com valor inválido" do
    get "/up"
    expect(request.remote_ip).to eq("127.0.0.1")

    get "/up", headers: { "X-Real-IP" => "não-é-um-ip" }
    expect(request.remote_ip).to eq("127.0.0.1")
  end

  it "limita o mesmo visitante mesmo quando o proxy muda a cada requisição" do
    5.times { post_contact("203.0.113.9") }
    post_contact("203.0.113.9")

    expect(response).to redirect_to(new_contact_path)
    expect(flash[:alert]).to include("Muitas tentativas")
  end

  it "não limita outro visitante por causa do primeiro" do
    6.times { post_contact("203.0.113.9") }
    post_contact("198.51.100.4")

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
