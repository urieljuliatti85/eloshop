module Admin
  class MercadoPagoTestAccountsController < BaseController
    before_action :set_test_account, only: %i[edit update destroy]

    def index
      @test_accounts = MercadoPagoTestAccount.order(:account_type, :label)
    end

    def new
      @test_account = MercadoPagoTestAccount.new
    end

    def create
      @test_account = MercadoPagoTestAccount.new(test_account_params)

      if @test_account.save
        redirect_to admin_mercado_pago_test_accounts_path, notice: "Conta de teste criada com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @test_account.update(test_account_params)
        redirect_to admin_mercado_pago_test_accounts_path, notice: "Conta de teste atualizada com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @test_account.destroy
      redirect_to admin_mercado_pago_test_accounts_path, notice: "Conta de teste removida."
    end

    private

    def set_test_account
      @test_account = MercadoPagoTestAccount.find(params[:id])
    end

    def test_account_params
      params.expect(mercado_pago_test_account: %i[account_type label email mercado_pago_user_id username password verification_code])
    end
  end
end
