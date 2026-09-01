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
    post session_path, params: { email_address: user.email_address, password: password }
    follow_redirect! if response.redirect?
  end

  def sign_out
    delete session_path if respond_to?(:delete)
  end

  def approved_seller
    @approved_seller ||= Seller.create!(
      name: "Ateliê Spec #{SecureRandom.hex(4)}",
      status: :approved,
      approved_at: Time.current
    )
  end
end
