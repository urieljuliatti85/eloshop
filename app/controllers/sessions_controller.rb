class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Tente novamente mais tarde." }

  def new
  end

  # Sempre texto: sem a senha no POST, `authenticate_by` levantava
  # ArgumentError e a porta respondia 500 (achado do QA, 2026-11-07).
  def create
    if user = User.authenticate_by(email_address: params[:email_address].to_s, password: params[:password].to_s)
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "E-mail ou senha inválidos."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
