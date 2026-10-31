module SellerPortal
  # Aba "Cadastro da Chave Pix": passo a passo estático, o mesmo para todos.
  # Só o estado da confirmação (`current_seller.pix_key_confirmed_at`) muda a
  # página. O passo vem em `?passo=N` (links, sem JavaScript); valor inválido
  # cai no passo 1.
  class PixKeyGuidesController < BaseController
    STEPS = [
      { title: "Toque em Pix", text: "Abra o app do Mercado Pago, na conta que você conectou à EloShop, e toque em Pix no menu de baixo." },
      { title: "Abra a Área Pix", text: "Na tela do Pix, toque no ícone de quatro quadradinhos, no canto superior direito, circulado na imagem." },
      { title: "Cadastre uma chave", text: "Em Minhas chaves, toque em Cadastrar." },
      { title: "Continue", text: "O app explica que você pode ter até 5 chaves e que as chaves do Mercado Pago não podem ser cadastradas em outro banco. Toque em Continuar." },
      { title: "Escolha o tipo de chave", text: "Celular, CPF, e-mail ou chave aleatória. Qualquer uma serve; a aleatória não expõe nenhum dado seu." },
      { title: "Cadastre a chave", text: "Revise os dados e toque em Cadastrar chave. Depois volte aqui e clique em \"Já cadastrei minha chave PIX\"." }
    ].freeze

    def show
      @steps = STEPS
      @step = params[:passo].to_i.clamp(1, STEPS.size)
    end
  end
end
