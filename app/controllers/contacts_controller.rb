class ContactsController < StorefrontController
  allow_unauthenticated_customer_access

  CONFIRMATION_INTERVAL = 1.hour

  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_contact_path, alert: "Muitas tentativas. Tente novamente em alguns minutos." }

  def new
    @contact_message = ContactMessage.new
  end

  def create
    @contact_message = ContactMessage.new(contact_message_params)

    if @contact_message.valid?
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

  # Uma confirmação por e-mail por hora: o formulário é aberto, e sem esse
  # limite alguém poderia encher a caixa de um terceiro com confirmações. A
  # chave usa o hash do e-mail, nunca o endereço.
  def send_confirmation_once(email)
    key = "contact_confirmation:#{Digest::SHA256.hexdigest(email.to_s.strip.downcase)}"
    return unless Rails.cache.write(key, true, unless_exist: true, expires_in: CONFIRMATION_INTERVAL)

    ContactMailer.confirmation(email: email).deliver_later
  end

  def contact_message_params
    params.require(:contact_message).permit(:name, :email, :subject, :message)
  end
end
