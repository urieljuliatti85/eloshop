module SellerPortalHelper
  # Passos do tour guiado do painel. Cada um aponta para um link da navegação
  # (que existe em toda página do painel), então o tour nunca precisa
  # navegar: o controller `tour` localiza o link pelo `href`.
  def seller_tour_steps
    [
      { path: seller_getting_started_path, title: "Primeiros passos",
        body: "Comece por aqui: acompanhe o que já está pronto e o que falta para o seu ateliê vender." },
      { path: seller_atelier_path, title: "Dados do Ateliê",
        body: "Cadastre o endereço de origem do ateliê. Ele é usado nas suas entregas." },
      { path: seller_mercado_pago_guide_path, title: "Conta no Mercado Pago",
        body: "Conecte a conta que vai receber seus pagamentos. Sem ela não é possível publicar produtos.",
        alert: "Não se esqueça de cadastrar a sua chave pix na sua conta Mercado Pago!" },
      { path: seller_pix_key_guide_path, title: "Cadastro da Chave Pix",
        body: "Passo a passo, com imagens do app, para cadastrar uma chave PIX na sua conta do Mercado Pago.",
        alert: "Sem chave PIX, o pagamento por PIX dos seus clientes é recusado." },
      { path: new_seller_product_path, title: "Novo produto",
        body: "Cadastre sua primeira peça. Você pode salvar como rascunho e terminar depois." }
    ]
  end
end
