module ApplicationHelper
  # O item do menu fica marcado pelo controller da requisição, não pela URL
  # exata: "Loja" continua ativo na página de um produto, e "Painel do Artesão"
  # em qualquer tela do painel.
  def storefront_nav_active?(controllers)
    Array(controllers).include?(controller_path)
  end
end
