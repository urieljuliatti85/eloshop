# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Security headers", type: :request do
  let(:csp) do
    get root_path
    response.headers["Content-Security-Policy"]
  end

  def directive(name)
    csp[/(?:^|;)\s*#{name} ([^;]*)/, 1].to_s.split
  end

  it "sets a strict Content-Security-Policy with a non-empty nonce" do
    expect(csp).to include("default-src 'self'")
    expect(csp).to include("object-src 'none'")

    nonce = csp[/'nonce-([^']+)'/, 1]
    expect(nonce).to be_present
  end

  # A primeira entrega da Fase 24 liberou `https://*.mercadopago.com` e
  # `https://*.mlstatic.com`, o que é bem mais do que o Brick usa. Apertar
  # sem um teste deixaria o curinga voltar no primeiro susto de integração.
  it "não libera curinga de subdomínio em nenhuma diretiva" do
    expect(csp).not_to include("*.mercadopago.com")
    expect(csp).not_to include("*.mlstatic.com")
    expect(csp).not_to match(%r{https://\*})
  end

  # O iframe dos campos de cartão (`cacheUrl` do SDK) não serve script, e o
  # SDK só é buscado dos domínios de asset — trocar isso alargaria a
  # superfície sem necessidade.
  it "mantém cada domínio do Mercado Pago só na diretiva que o usa" do
    expect(directive("script-src")).to include("https://sdk.mercadopago.com", "https://api-static.mercadopago.com")
    expect(directive("script-src")).not_to include("https://secure-fields.mercadopago.com")

    expect(directive("frame-src")).to include("https://secure-fields.mercadopago.com")
    expect(directive("connect-src")).to include("https://api.mercadopago.com")

    # O mesmo domínio serve para dois usos: hospeda o iframe dos campos e
    # recebe XHR do SDK ao montar o Brick. Faltar em connect-src bloqueava a
    # montagem — observado no console em 2026-09-12.
    expect(directive("connect-src")).to include("https://secure-fields.mercadopago.com")
  end

  # script-src com nonce e SEM unsafe-inline é o que sustenta a política:
  # o afrouxamento de estilo inline (necessário para os <style> que o SDK
  # injeta) não pode transbordar para script.
  it "nunca permite script inline sem nonce" do
    expect(directive("script-src")).not_to include("'unsafe-inline'")
    expect(directive("script-src")).not_to include("'unsafe-eval'")
    expect(directive("script-src").grep(/\A'nonce-/)).not_to be_empty
  end

  # `unsafe-inline` em style-src só tem efeito se a diretiva NÃO tiver nonce:
  # o browser ignora um na presença do outro, e os <style> do SDK (criados em
  # runtime, sem nonce) seriam bloqueados.
  it "permite estilo inline sem nonce em style-src" do
    expect(directive("style-src")).to include("'unsafe-inline'")
    expect(directive("style-src").grep(/\A'nonce-/)).to be_empty
  end
end
