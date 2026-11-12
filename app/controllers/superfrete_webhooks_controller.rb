# Webhook de rastreio da SuperFrete (ADR 005). Um webhook por conta de
# ateliê: a chave na URL acha o ateliê e o segredo dele, e a autenticidade
# vem da assinatura — HMAC-SHA256 do corpo bruto com o `secret_token`, em
# hexadecimal e sem prefixo (confirmado pela SuperFrete em 2026-11-11).
#
# `skip_forgery_protection` de propósito, como em PaymentWebhooksController:
# quem chama é o servidor da SuperFrete, sem token CSRF.
#
# Chave desconhecida e assinatura errada respondem igual (401), para a
# resposta não confirmar quais chaves existem. Notificação válida responde
# 200 mesmo quando não há o que fazer: o processamento é em job e a
# SuperFrete espera resposta em até 10 segundos.
class SuperfreteWebhooksController < ApplicationController
  skip_forgery_protection
  allow_unauthenticated_access
  rate_limit to: 300, within: 1.minute, with: -> { head :too_many_requests }

  def create
    # Só a chave da rota: `params` interpretaria o corpo JSON, e um corpo
    # inválido estouraria antes da verificação da assinatura.
    key = request.path_parameters[:key].to_s
    seller = Seller.find_by(superfrete_webhook_key: key) if key.present?
    return head :unauthorized unless seller && valid_signature?(seller)

    event = ShippingLabelEvent.record(seller: seller, body: request.raw_post)
    ProcessShippingLabelEventJob.perform_later(event) if event
    head :ok
  end

  private

  def valid_signature?(seller)
    secret = seller.superfrete_webhook_secret
    signature = request.headers["X-ME-Signature"].to_s.strip.downcase
    return false if secret.blank? || signature.blank?

    expected = OpenSSL::HMAC.hexdigest("SHA256", secret, request.raw_post.to_s)
    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end
end
