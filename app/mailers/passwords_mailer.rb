class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Redefinição de senha", to: user.email_address
  end
end
