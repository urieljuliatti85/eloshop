module Admin
  # Quem pode chamar a API v1 e ler /api-docs. Sem edição nem exclusão:
  # revogar preserva o registro de quem teve acesso, e um token novo é um
  # cliente novo.
  class ApiClientsController < BaseController
    def index
      @api_clients = paginate(ApiClient.order(revoked_at: :desc, created_at: :desc))
    end

    def new
      @api_client = ApiClient.new
    end

    # Renderiza o token em vez de redirecionar: ele só existe em texto puro
    # agora, e passá-lo pelo flash o gravaria no cookie de sessão.
    def create
      @api_client = ApiClient.new(api_client_params)

      if @api_client.save
        response.headers["Cache-Control"] = "no-store"
        render :created, status: :created
      else
        render :new, status: :unprocessable_entity
      end
    end

    def revoke
      api_client = ApiClient.find(params[:id])
      api_client.revoke!

      redirect_to admin_api_clients_path, notice: "Acesso de #{api_client.name} revogado."
    end

    private

    def api_client_params
      params.expect(api_client: %i[name])
    end
  end
end
