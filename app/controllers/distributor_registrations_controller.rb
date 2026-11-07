# Cadastro do distribuidor de insumos (ADR 007, Fase 25), em /atacado/cadastro.
# Sempre com um `User` novo: um ateliê não vira distribuidor, e o tipo é fixo
# depois do cadastro. Reaproveita o cadastro do ateliê inteiro (rate limit,
# Turnstile, termos gravados na mesma transação, log sem dados pessoais) e só
# troca o tipo, os campos de empresa e as telas.
#
# Atrás de `config.x.distributors.signup_enabled`: ligado fora de produção,
# desligado em produção até o advogado revisar o rascunho dos termos do
# distribuidor (decisão do Uriel, 2026-11-07). Desligado, a página não existe.
class DistributorRegistrationsController < SellerRegistrationsController
  before_action :require_signup_enabled

  def self.signup_enabled?
    Rails.configuration.x.distributors.signup_enabled == true
  end

  private

  def require_signup_enabled
    raise ActionController::RoutingError, "Not Found" unless self.class.signup_enabled?
  end

  def seller_kind
    "distributor"
  end

  def registration_form_path(...)
    new_distributor_registration_path(...)
  end

  # O e-mail de boas-vindas fala de ateliê, peças e frete por peça; o do
  # distribuidor chega com o catálogo de insumos (Fase 26).
  def sends_welcome_email?
    false
  end

  # `issues_invoices` é a declaração pública de nota fiscal: coletada e
  # opcional até a consulta jurídica (ADR 007); em branco fica `nil`.
  def seller_params
    permitted = params.expect(seller: [ :name, :owner_full_name, :cpf, :cnpj, :issues_invoices ])
    permitted[:issues_invoices] = permitted[:issues_invoices].presence
    permitted
  end
end
