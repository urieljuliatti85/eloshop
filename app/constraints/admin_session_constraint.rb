# Restringe rotas montadas (engines, fora de qualquer controller) ao admin da
# plataforma, lendo a mesma sessão de `Authentication`. Quem não passa recebe
# 404 do roteador, sem revelar que a rota existe.
class AdminSessionConstraint
  def self.matches?(request)
    session_id = request.cookie_jar.signed[:session_id]
    return false unless session_id

    Session.active.find_by(id: session_id)&.user&.admin? || false
  end
end
