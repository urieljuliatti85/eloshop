class SellerRegistrationsController < ApplicationController
  include EmailAbuseProtection

  RATE_LIMIT_MESSAGE = "Foram muitas tentativas de cadastro em pouco tempo. Por segurança, aguarde 15 minutos e tente de novo.".freeze
  EXPIRED_FORM_MESSAGE = "O formulário expirou por segurança: ele ficou aberto por muito tempo ou você entrou ou saiu de uma conta em outra aba. Confira os dados, digite a senha de novo e envie outra vez.".freeze

  allow_unauthenticated_access
  rate_limit to: 5, within: 15.minutes, only: :create,
    with: -> { redirect_to registration_form_path(anchor: "cadastro"), alert: RATE_LIMIT_MESSAGE }

  # Sem isto, o token de formulário vencido caía na página 422 padrão do Rails
  # — em inglês e sem dizer o que fazer. Só reapresenta o formulário: nada é
  # gravado, então não abre brecha de CSRF.
  rescue_from ActionController::InvalidAuthenticityToken, with: :render_expired_form

  rate_limit to: 60, within: 1.minute, only: :name_availability, with: -> { head :too_many_requests }

  def name_availability
    render json: Seller.name_availability(params[:name].to_s.first(120))
  end

  def new
    @seller = Seller.new(kind: seller_kind)
    @user = User.new(role: :seller)
  end

  def create
    @seller = Seller.new(seller_params.merge(kind: seller_kind))
    @user = User.new(user_params.merge(role: :seller, seller: @seller))

    # Valida tudo antes de decidir, e não `@seller.valid? && @user.valid?`: o
    # `&&` parava no primeiro inválido e escondia os erros da conta. A tela
    # lista todos de uma vez, inclusive com o Turnstile recusado, para o
    # artesão não descobrir um erro novo a cada tentativa.
    seller_valid = @seller.valid?
    user_valid = @user.valid?

    unless turnstile_passed?
      @user.errors.add(:base, TURNSTILE_ERROR)
      add_terms_error
      return render_registration_errors
    end

    if seller_valid && user_valid && params[:terms_accepted] == "1"
      Seller.transaction do
        @seller.save!
        @user.save!
        SellerTermsAcceptance.record!(user: @user, seller: @seller, request: request)
      end
      welcome_queued = sends_welcome_email? && account_email_budget_available?
      SendWelcomeSellerJob.perform_later(@seller, @user.email_address) if welcome_queued
      start_new_session_for(@user)
      notice = "Cadastro recebido. A publicação será liberada após a aprovação da plataforma."
      notice += " #{SPAM_HINT}" if welcome_queued
      redirect_to seller_panel_path_for(@seller), notice: notice
    else
      add_terms_error
      render_registration_errors
    end
  rescue ActiveRecord::RecordNotUnique
    # Corrida: outro cadastro gravou o mesmo CPF (no mesmo tipo) ou o mesmo
    # e-mail entre a validação e o INSERT. Validar de novo agora encontra o
    # registro concorrente e mostra o erro do campo certo; antes, CPF repetido
    # aparecia como "e-mail já está em uso" (achado do QA, 2026-11-07).
    @seller.valid?
    @user.valid?
    @user.errors.add(:email_address, "já está em uso") if @seller.errors.empty? && @user.errors.empty?
    render_registration_errors
  end

  private

  # Pontos que o cadastro do distribuidor (`DistributorRegistrationsController`,
  # ADR 007) troca; o resto — validação completa, Turnstile, rate limit, termos
  # gravados na mesma transação e o log sem dados pessoais — é o mesmo.
  def seller_kind
    "atelier"
  end

  def registration_form_path(...)
    new_seller_registration_path(...)
  end

  def sends_welcome_email?
    true
  end

  # O evento leva só atributo e tipo do erro (`cpf_hash: taken`), nunca o
  # valor digitado: CPF, e-mail e senha não vão para log nem Sentry (§43). É o
  # que permite saber por que um cadastro falhou sem perguntar ao artesão.
  def render_registration_errors
    Rails.event.notify("marketplace.seller_registration_failed",
      seller_errors: error_kinds(@seller), user_errors: error_kinds(@user))
    render :new, status: :unprocessable_entity
  end

  def error_kinds(record)
    # O tipo é um símbolo (`:taken`) ou o texto fixo que o model escreveu
    # ("deve ter 11 dígitos") — nunca o valor que a pessoa digitou.
    record.errors.map { |error| "#{error.attribute}:#{error.type}" }
  end

  def render_expired_form
    @seller = Seller.new(seller_params.merge(kind: seller_kind))
    @user = User.new(user_params.except(:password, :password_confirmation).merge(role: :seller, seller: @seller))
    @user.errors.add(:base, EXPIRED_FORM_MESSAGE)
    render_registration_errors
  rescue ActionController::ParameterMissing
    @seller = Seller.new(kind: seller_kind)
    @user = User.new(role: :seller)
    @user.errors.add(:base, EXPIRED_FORM_MESSAGE)
    render_registration_errors
  end

  def add_terms_error
    @user.errors.add(:base, "aceite os termos comerciais para criar o cadastro") unless params[:terms_accepted] == "1"
  end

  def seller_params
    params.expect(seller: [ :name, :owner_full_name, :cpf ])
  end

  def user_params
    params.expect(user: %i[email_address password password_confirmation])
  end
end
