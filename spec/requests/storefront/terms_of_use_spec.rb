# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Terms of use", type: :request do
  it "is public and covers purchase, refunds and the platform's role" do
    get terms_of_use_path

    expect(response).to have_http_status(:ok)
    body = Nokogiri::HTML(response.body).text.squish
    expect(body).to include("Termos de Uso")
    expect(body).to include("Cada peça é vendida pelo ateliê que a produz")
    expect(body).to include("A EloShop não recebe nem guarda os dados do seu cartão")
    expect(body).to include("desistir da compra em até 7 dias corridos do recebimento")
    expect(body).to include("Nada nestes termos limita direitos que a lei garante ao consumidor")
  end

  # Mesma linha do parecer jurídico de 2026-10-29: nada de decisão final da
  # plataforma nem limite de desistência pelo início da produção.
  it "does not promise a final platform decision nor limit withdrawal by production" do
    get terms_of_use_path

    expect(response.body).not_to include("a EloShop decide")
    expect(response.body).not_to include("até o ateliê iniciar a produção")
  end

  it "is linked from the footer" do
    get root_path

    expect(Nokogiri::HTML(response.body).css("footer a").map { |a| a["href"] }).to include(terms_of_use_path)
  end
end
