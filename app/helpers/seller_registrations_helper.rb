module SellerRegistrationsHelper
  # Erros do cadastro de artesão com a explicação de cada um: o que aconteceu e
  # o que fazer. A mensagem do model diz o quê ("CPF já está cadastrado para
  # outro ateliê"); a dica diz por quê e como seguir, que era o que faltava —
  # o artesão via o formulário voltar e não sabia o que corrigir.
  #
  # Cada item: { attribute:, message:, hint:, link: } — `link` é [texto, url]
  # quando o caminho é outra página (entrar com a conta que já existe).
  def registration_errors(*records)
    records.flat_map do |record|
      record.errors.map do |error|
        hint, link = registration_error_hint(record, error)
        { attribute: error.attribute, message: error.full_message, hint: hint, link: link }
      end
    end
  end

  def registration_errors_for(errors, *attributes)
    errors.select { |error| attributes.include?(error[:attribute]) }
  end

  private

  # O distribuidor (ADR 007) usa as mesmas dicas, com o próprio nome e a
  # própria porta de login.
  def registration_error_hint(record, error)
    distributor = @seller&.distributor?
    login_link = distributor ? [ "Entrar no painel do armarinho", distributor_login_path ] : [ "Entrar no painel do ateliê", seller_login_path ]

    case [ record.class.name, error.attribute, error.type ]
    in [ "Seller", :cpf_hash, :taken ] if distributor
      [ "Cada CPF pode ter um único cadastro de armarinho na EloShop. Se este cadastro já é seu, entre no painel com a conta que você criou.", login_link ]
    in [ "Seller", :cpf_hash, :taken ]
      [ "Cada CPF pode ter um único ateliê na EloShop. Se este ateliê já é seu, entre no painel com a conta que você criou.", login_link ]
    in [ "Seller", :cnpj, _ ]
      [ "O CNPJ tem 14 caracteres: 12 letras ou números e 2 dígitos no fim. Confira se algum foi digitado errado, ou deixe o campo em branco." ]
    in [ "Seller", :cpf, "deve ter 11 dígitos" ]
      [ "O CPF tem 11 números. Confira se faltou ou sobrou algum." ]
    in [ "Seller", :cpf, "é inválido" ]
      [ "Os números não formam um CPF válido. Confira se algum foi digitado errado." ]
    in [ "Seller", :slug, :taken ] if distributor
      [ "Já existe um vendedor com esse nome na EloShop. Escolha outro nome." ]
    in [ "Seller", :slug, :taken ]
      [ "Já existe um ateliê com esse nome, e o endereço da página sairia igual. Escolha outro nome." ]
    in [ "User", :email_address, :taken | "já está em uso" ] if distributor
      [ "Já existe uma conta com este e-mail. Se ela é do seu armarinho, entre no painel; se é de um ateliê, use outro e-mail, porque cada conta tem um tipo só.", login_link ]
    in [ "User", :email_address, :taken | "já está em uso" ]
      [ "Já existe uma conta com este e-mail. Se ela é sua, entre no painel; senão, use outro e-mail.", login_link ]
    in [ "User", :password_confirmation, :confirmation ]
      [ "Digite a mesma senha nos dois campos." ]
    in [ "User", :base, EmailAbuseProtection::TURNSTILE_ERROR ]
      [ "É a verificação anti-robô da Cloudflare, logo acima do botão. Espere o quadro confirmar a verificação antes de clicar em \"Criar cadastro\"." ]
    in [ "User", :base, "aceite os termos comerciais para criar o cadastro" ]
      [ "Marque a caixa dos Termos Comerciais, logo acima do botão." ]
    else
      nil
    end
  end
end
