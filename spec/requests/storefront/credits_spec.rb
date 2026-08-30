# frozen_string_literal: true

require "rails_helper"

# CC BY e CC BY-SA exigem atribuição visível de quem publica a imagem. Esta
# página é o que cumpre essa obrigação, então ela precisa estar aberta e
# mostrar autor, licença e origem de cada foto.
RSpec.describe "Credits", type: :request do
  describe "GET /creditos" do
    it "abre sem autenticação" do
      get credits_path

      expect(response).to have_http_status(:ok)
    end

    it "mostra autor, licença e origem de cada foto de terceiro" do
      credit = ImageCredit.all.find(&:attribution_required?)
      skip "nenhuma imagem exige atribuição" if credit.nil?

      get credits_path

      expect(response.body).to include(ERB::Util.html_escape(credit.autor))
      expect(response.body).to include(ERB::Util.html_escape(credit.licenca))
      expect(response.body).to include(credit.origem_url)
    end

    # Brakeman (LinkToHref) aponta href vinda de dado externo. O YAML é do
    # repositório, mas um `javascript:` ali viraria XSS na página pública.
    it "não transforma URL de esquema perigoso em link" do
      perigoso = ImageCredit.new(
        "produto" => "Peça de teste", "titulo" => "Titulo", "autor" => "Autor",
        "licenca" => "CC BY 4.0",
        "licenca_url" => "javascript:alert(1)",
        "origem_url" => "javascript:alert(2)"
      )

      expect(perigoso.licenca_url).to be_nil
      expect(perigoso.origem_url).to be_nil
    end

    it "mantém URLs http e https" do
      ok = ImageCredit.new(
        "licenca_url" => "https://creativecommons.org/licenses/by/4.0/",
        "origem_url" => "http://exemplo.test/foto"
      )

      expect(ok.licenca_url).to eq("https://creativecommons.org/licenses/by/4.0/")
      expect(ok.origem_url).to eq("http://exemplo.test/foto")
    end

    it "é alcançável a partir do rodapé de qualquer página da loja" do
      get root_path

      expect(response.body).to include(credits_path)
    end
  end
end
