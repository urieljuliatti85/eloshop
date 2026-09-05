module Admin
  # Quem administra a plataforma. `BaseController` já exige admin, então não
  # há verificação extra aqui.
  class AdminsController < BaseController
    def index
      @admins = User.admin.order(:email_address)
    end

    def new
      @admin = User.new
    end

    def create
      @admin = User.new(admin_params.merge(role: :admin))

      if @admin.save
        redirect_to admin_admins_path, notice: "Administrador criado com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # Duas saídas bloqueadas: remover a si mesmo (o admin se trancaria para
    # fora no meio da própria sessão) e remover o último admin, que o modelo
    # recusa e a plataforma ficaria sem quem a administre.
    def destroy
      admin = User.admin.find(params[:id])

      if admin == Current.user
        return redirect_to admin_admins_path, alert: "Você não pode remover a sua própria conta."
      end

      if admin.destroy
        redirect_to admin_admins_path, notice: "Administrador removido."
      else
        redirect_to admin_admins_path, alert: admin.errors.full_messages.to_sentence
      end
    end

    private

    def admin_params
      params.expect(user: %i[email_address password password_confirmation])
    end
  end
end
