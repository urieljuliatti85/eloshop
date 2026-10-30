# Porta da documentação da API (/api-docs: Swagger UI e swagger.yaml). Entra
# o admin da plataforma logado, pela mesma sessão de `Authentication`, ou quem
# tem um `ApiClient` ativo, por HTTP Basic com o token como senha (o usuário é
# livre: o token sozinho identifica o cliente). Fica em volta dos engines do
# rswag porque eles não passam pelos controllers da aplicação, e é um
# middleware, não uma restrição de rota, porque o Basic precisa responder 401
# com o desafio — a restrição só sabe devolver 404.
class ApiDocsAuthentication
  REALM = "EloShop API docs"

  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    return @app.call(env) if admin_session?(request)

    api_client = api_client_from_basic(request)
    return unauthorized unless api_client

    api_client.track_usage!
    @app.call(env)
  end

  private

  def admin_session?(request)
    session_id = request.cookie_jar.signed[:session_id]
    return false unless session_id

    Session.active.find_by(id: session_id)&.user&.admin? || false
  end

  def api_client_from_basic(request)
    return unless ActionController::HttpAuthentication::Basic.has_basic_credentials?(request)

    _user, token = ActionController::HttpAuthentication::Basic.user_name_and_password(request)
    ApiClient.authenticate(token)
  end

  def unauthorized
    [ 401, { "content-type" => "text/plain; charset=utf-8", "www-authenticate" => %(Basic realm="#{REALM}", charset="UTF-8") }, [ "Acesso restrito." ] ]
  end
end
