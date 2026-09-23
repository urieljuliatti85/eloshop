module AuthenticationHelpers
  # Remove as fixtures de produto para que o exemplo asserte sobre um catálogo
  # que ele mesmo cria.
  #
  # DELETE, e não TRUNCATE: TRUNCATE pega ACCESS EXCLUSIVE na tabela e
  # serializa contra qualquer outra conexão no banco de teste. Com um segundo
  # processo em jogo — o Puma dos testes de sistema, ou uma conexão
  # remanescente — a suíte inteira travava esperando o lock, e em alguns
  # entrelaçamentos estourava PG::TRDeadlockDetected (um lado pedindo ACCESS
  # EXCLUSIVE, o outro ACCESS SHARE). Medido: com uma conexão concorrente
  # segurando `products` por 40s, a suíte de models ia de ~2s para 40s.
  #
  # DELETE usa lock de linha e não bloqueia leitor concorrente. Como o exemplo
  # roda em transação (use_transactional_fixtures), o efeito é revertido do
  # mesmo jeito — e sem RESTART IDENTITY, que além de desnecessário reinicia
  # sequências fora da transação (reset de sequência não é transacional no
  # PostgreSQL).
  #
  # A ordem respeita as foreign keys: filhos antes de products.
  PRODUCT_DATA_MODELS = [
    CartItem, OrderItem, PersonalizationOption, ProductVariant,
    ProductTag, ProductMaterial, ProductTechnique, Review, WishlistItem, Product
  ].freeze

  def clear_product_data!
    PRODUCT_DATA_MODELS.each(&:delete_all)
  end

  def sign_in_as(user, password: "password123")
    accept_current_seller_terms(user)
    post session_path, params: { email_address: user.email_address, password: password }
    follow_redirect! if response.redirect?
  end

  def sign_out
    delete session_path if respond_to?(:delete)
  end

  def approved_seller
    @approved_seller ||= begin
      seller = Seller.create!(
        name: "Ateliê Spec #{SecureRandom.hex(4)}",
        owner_full_name: "Proprietário Spec",
        cpf: generate_valid_cpf,
        status: :approved,
        approved_at: Time.current
      )
      user = User.create!(
        email_address: "seller-terms-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: :seller,
        seller: seller
      )
      SellerTermsAcceptance.record!(user: user, seller: seller, request: ActionDispatch::TestRequest.create)
      seller
    end
  end

  def accept_current_seller_terms(user)
    return unless user.seller?

    SellerTermsAcceptance.record!(
      user: user,
      seller: user.seller,
      request: ActionDispatch::TestRequest.create
    )
  end

  # Gera um CPF com dígitos verificadores válidos (módulo 11) para satisfazer
  # `Seller#cpf_must_be_valid` em specs que não testam CPF diretamente.
  def generate_valid_cpf
    base = Array.new(9) { rand(10) }
    base = base.map.with_index { |digit, i| i.zero? ? rand(1..9) : digit } # evita sequência 000000000
    d1 = check_digit(base)
    d2 = check_digit(base + [ d1 ])
    (base + [ d1, d2 ]).join
  end

  def check_digit(digits)
    weights = (digits.length + 1).downto(2)
    sum = digits.zip(weights).sum { |digit, weight| digit * weight }
    remainder = (sum * 10) % 11
    remainder == 10 ? 0 : remainder
  end
end
