module SellerPortal
  class SessionsController < ApplicationController
    allow_unauthenticated_access only: %i[ new create ]
    rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to seller_login_path, alert: "Tente novamente mais tarde." }

    def new
    end

    # Mesma credencial de `SessionsController`, mas só aceita quem já é
    # vendedor: esta porta é do ateliê, não do admin da plataforma. Um admin
    # com senha correta recebe a mesma mensagem de e-mail/senha inválidos —
    # não confirma que a conta existe nem qual é o papel dela.
    def create
      user = User.authenticate_by(params.permit(:email_address, :password))
      if user&.seller?
        start_new_session_for user
        redirect_to after_authentication_url
      else
        redirect_to seller_login_path, alert: "E-mail ou senha inválidos."
      end
    end

    def destroy
      terminate_session
      redirect_to seller_login_path, status: :see_other
    end
  end
end
