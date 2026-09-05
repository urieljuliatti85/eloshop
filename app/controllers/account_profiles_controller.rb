# Dados de cadastro do cliente. A troca de senha é opcional: em branco, os
# demais campos são salvos sem tocar na senha.
class AccountProfilesController < StorefrontController
  def edit
    @customer = Current.customer
  end

  def update
    @customer = Current.customer

    # Trocar a senha exige confirmar a atual: sem isso, uma sessão roubada
    # troca a senha e toma a conta em definitivo.
    if profile_params[:password].present? && !@customer.authenticate(params[:customer][:current_password].to_s)
      @customer.errors.add(:current_password, "não confere")
      return render :edit, status: :unprocessable_entity
    end

    if @customer.update(profile_params)
      redirect_to account_root_path, notice: "Cadastro atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    permitted = params.expect(customer: %i[name email password password_confirmation])
    # Senha em branco significa "não trocar", não "apagar".
    permitted[:password].blank? ? permitted.except(:password, :password_confirmation) : permitted
  end
end
