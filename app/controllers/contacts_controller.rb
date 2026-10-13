class ContactsController < StorefrontController
  allow_unauthenticated_customer_access

  CONFIRMATION_INTERVAL = 1.hour

  # Tetos globais por dia (todos os visitantes somados): o Resend tem cota
  # diária compartilhada com e-mails de pedido e de senha, e o spam por IP
  # distribuído já a esgotou. Passou do teto, o formulário para de enviar.
  DAILY_NOTIFY_LIMIT = 30
  DAILY_CONFIRMATION_LIMIT = 15

  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_contact_path, alert: "Muitas tentativas. Tente novamente em alguns minutos." }

  # TEMPORÁRIO: descobrir qual cabeçalho traz o IP real do visitante atrás de
  # Cloudflare + Railway (o `remote_ip` chega como 100.64.0.x). Remover junto
  # com a correção do IP.
  before_action :log_client_ip_headers, only: :create

  def new
    @contact_message = ContactMessage.new
  end

  def create
    @contact_message = ContactMessage.new(contact_message_params)

    case ContactMessage.rejection_for(token: params[:form_token], honeypot: params[:website])
    when :honeypot
      # Bot: finge sucesso para não dar sinal do que o barrou.
      return redirect_to new_contact_path, notice: "Mensagem enviada! Vamos responder em até 2 dias úteis."
    when :token
      @contact_message.errors.add(:base, "Não foi possível enviar. Recarregue a página e tente de novo.")
      return render :new, status: :unprocessable_entity
    end

    if @contact_message.valid?
      unless within_daily_budget?("notify", DAILY_NOTIFY_LIMIT)
        Rails.logger.warn("contact_daily_limit_reached")
        return redirect_to new_contact_path, alert: "Estamos com muitas mensagens no momento. Tente novamente mais tarde."
      end

      ContactMailer.notify(
        name: @contact_message.name,
        email: @contact_message.email,
        subject: @contact_message.subject,
        message: @contact_message.message
      ).deliver_later
      send_confirmation_once(@contact_message.email)
      redirect_to new_contact_path, notice: "Mensagem enviada! Vamos responder em até 2 dias úteis."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def log_client_ip_headers
    Rails.logger.info(
      "client_ip_diagnostic remote_ip=#{request.remote_ip} " \
      "remote_addr=#{request.env['REMOTE_ADDR']} " \
      "x_real_ip=#{request.headers['X-Real-IP'].inspect} " \
      "x_forwarded_for=#{request.headers['X-Forwarded-For'].inspect} " \
      "cf_connecting_ip=#{request.headers['CF-Connecting-IP'].inspect}"
    )
  end

  # Uma confirmação por e-mail por hora: o formulário é aberto, e sem esse
  # limite alguém poderia encher a caixa de um terceiro com confirmações. A
  # chave usa o hash do e-mail, nunca o endereço.
  def send_confirmation_once(email)
    key = "contact_confirmation:#{Digest::SHA256.hexdigest(email.to_s.strip.downcase)}"
    return unless Rails.cache.write(key, true, unless_exist: true, expires_in: CONFIRMATION_INTERVAL)
    return unless within_daily_budget?("confirmation", DAILY_CONFIRMATION_LIMIT)

    ContactMailer.confirmation(email: email).deliver_later
  end

  def within_daily_budget?(name, limit)
    key = "contact_budget:#{name}:#{Date.current.iso8601}"
    Rails.cache.write(key, 0, unless_exist: true, expires_in: 2.days)
    Rails.cache.increment(key).to_i <= limit
  end

  def contact_message_params
    params.require(:contact_message).permit(:name, :email, :subject, :message)
  end
end
