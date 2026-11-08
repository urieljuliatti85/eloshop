class DistributorInterestsController < StorefrontController
  include EmailAbuseProtection

  allow_unauthenticated_customer_access

  NOTIFY_LIMIT = ContactsController::DAILY_NOTIFY_LIMIT
  CONFIRMATION_LIMIT = ContactsController::DAILY_CONFIRMATION_LIMIT

  rate_limit to: 5, within: 10.minutes, only: :create,
    with: -> {
      redirect_to new_distributor_interest_path,
        alert: "Muitas tentativas. Aguarde alguns minutos e tente de novo."
    }

  def new
    @interest = DistributorInterest.new
  end

  def create
    email = interest_params[:email_address].to_s.strip.downcase
    @interest = DistributorInterest.find_or_initialize_by(email_address: email)
    first_request = @interest.new_record?
    @interest.whatsapp_number = interest_params[:whatsapp_number]
    @interest.consent_at = params[:consent] == "1" ? Time.current : nil
    @interest.notified_at = nil if @interest.persisted? && params[:consent] == "1"

    case ContactMessage.rejection_for(token: params[:form_token], honeypot: params[:website])
    when :honeypot
      return redirect_to new_distributor_interest_path,
        notice: "Recebemos seu interesse. Avisaremos quando o pré-cadastro abrir."
    when :token
      @interest.errors.add(:base, "Recarregue a página e tente novamente.")
      return render :new, status: :unprocessable_entity
    end

    unless turnstile_passed?
      @interest.errors.add(:base, TURNSTILE_ERROR)
      return render :new, status: :unprocessable_entity
    end

    if @interest.save
      notify_team(@interest) if first_request
      confirm_to_visitor(@interest.email_address) if first_request
      redirect_to new_distributor_interest_path,
        notice: "Recebemos seu interesse. Avisaremos quando o pré-cadastro abrir."
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    # Duas inscrições simultâneas para o mesmo e-mail: mantém um único contato.
    email = interest_params[:email_address].to_s.strip.downcase
    @interest = DistributorInterest.find_by!(email_address: email)
    @interest.update(whatsapp_number: interest_params[:whatsapp_number], consent_at: Time.current, notified_at: nil)
    redirect_to new_distributor_interest_path,
      notice: "Recebemos seu interesse. Avisaremos quando o pré-cadastro abrir."
  end

  private

  def interest_params
    params.expect(distributor_interest: %i[email_address whatsapp_number])
  end

  def notify_team(interest)
    unless within_daily_budget?("contact_notify", NOTIFY_LIMIT)
      Rails.logger.warn("distributor_interest_notification_daily_limit_reached")
      return
    end

    ContactMailer.distributor_interest(email: interest.email_address, whatsapp: interest.whatsapp_number).deliver_later
  rescue StandardError => error
    Rails.logger.error("distributor_interest_notification_enqueue_failed error=#{error.class}")
  end

  def confirm_to_visitor(email)
    key = "distributor_interest_confirmation:#{Digest::SHA256.hexdigest(email)}"
    return unless Rails.cache.write(key, true, unless_exist: true, expires_in: 1.hour)
    return unless within_daily_budget?("contact_confirmation", CONFIRMATION_LIMIT)

    ContactMailer.distributor_interest_confirmation(email: email).deliver_later
  rescue StandardError => error
    Rails.logger.error("distributor_interest_confirmation_enqueue_failed error=#{error.class}")
  end
end
