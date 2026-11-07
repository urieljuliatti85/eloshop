# frozen_string_literal: true

require "rails_helper"

# O painel em /painel é do ateliê; o distribuidor tem o dele em
# /atacado/painel (ADR 007). Um controller de `SellerPortal` só aceita
# distribuidor se estiver na lista abaixo, revista de propósito: liberar o
# tipo no controller errado (ou herdar de uma base liberada) deixaria o
# distribuidor criar dado de ateliê — produto, tema, frete — antes da fase
# dele (revisão de arquitetura de 2026-11-07). As telas que os dois painéis
# compartilham entram no painel do distribuidor por subclasse em
# `DistributorPortal`, não por aqui. Fica no RSpec para valer já no
# pre-commit.
RSpec.describe "Guarda do painel do ateliê contra o distribuidor" do
  # A única exceção: o redirect URI registrado no Mercado Pago é um só, em
  # /painel, então a conexão serve aos dois tipos e devolve cada um ao seu
  # painel.
  ACCEPTS_DISTRIBUTOR = %w[SellerPortal::MercadoPagoConnectionsController].freeze

  it "lets a distributor into no atelier panel controller beyond the reviewed list" do
    Rails.application.eager_load!

    accepting = SellerPortal::BaseController.descendants
      .select { |controller| controller.name&.start_with?("SellerPortal::") }
      .select { |controller| controller.seller_portals.include?(:distributor) }
      .map(&:name).sort

    expect(accepting).to eq(ACCEPTS_DISTRIBUTOR.sort),
      "Controllers de /painel que aceitam distribuidor: #{accepting.inspect}. " \
      "Se for de propósito, revise e acrescente a ACCEPTS_DISTRIBUTOR; senão, " \
      "a tela compartilhada entra pelo painel do distribuidor (DistributorPortal)."
  end

  it "keeps the atelier panel base closed to distributors" do
    expect(SellerPortal::BaseController.seller_portals).to eq(%i[atelier])
  end
end
