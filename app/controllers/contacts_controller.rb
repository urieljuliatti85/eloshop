class ContactsController < StorefrontController
  allow_unauthenticated_customer_access

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
      redirect_to new_contact_path, notice: "Mensagem enviada! Vamos responder em breve."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def contact_message_params
    params.require(:contact_message).permit(:name, :email, :subject, :message)
  end
end
