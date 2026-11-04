# Categoria que um ateliê pediu por não achar a dele na lista. O admin aceita
# (escolhendo a categoria-mãe e podendo corrigir o nome) ou recusa; todos os
# ateliês que sugeriram o mesmo nome recebem a decisão por e-mail.
#
# Sugestões iguais viram uma só pela `normalized_key`, a mesma regra do slug
# de Category (`parameterize`: ignora caixa, acento e espaço). Quem garante é
# o índice único parcial sobre as pendentes, não a checagem em Ruby: dois
# ateliês sugerindo ao mesmo tempo caem na mesma linha. Recusada, a chave
# fica livre para uma sugestão nova (decisão de 2026-11-04).
#
# Aceitar não coloca a categoria no produto de ninguém: a plataforma não
# escreve no catálogo do ateliê, que escolhe a categoria depois do e-mail.
class CategorySuggestion < ApplicationRecord
  NAME_MAX_LENGTH = 60
  # Tamanho da coluna `normalized_key`. O `parameterize` pode crescer o nome
  # ("Æ" vira "ae", "ß" vira "ss"), então o limite do nome não basta.
  KEY_MAX_LENGTH = 80

  Result = Data.define(:outcome, :suggestion, :category)

  enum :status, { pending: "pending", accepted: "accepted", rejected: "rejected" }, default: "pending"

  belongs_to :category, optional: true
  belongs_to :decided_by_user, class_name: "User", optional: true
  has_many :requests, class_name: "CategorySuggestionRequest", dependent: :destroy, inverse_of: :category_suggestion
  has_many :sellers, through: :requests

  before_validation :normalize_name

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validate :name_has_letters_or_digits

  def self.normalize_key(name)
    name.to_s.squish.parameterize
  end

  # O ateliê pede uma categoria. Devolve um Result com o desfecho:
  # :created, :joined (outro ateliê já tinha sugerido), :already_requested,
  # :category_exists (com a categoria que já cobre o nome) ou :invalid.
  def self.suggest!(seller:, name:)
    candidate = new(name: name)
    return Result.new(outcome: :invalid, suggestion: candidate, category: nil) unless candidate.valid?

    if (existing = existing_category_for(candidate.normalized_key))
      return Result.new(outcome: :category_exists, suggestion: candidate, category: existing)
    end

    suggestion = pending_for!(candidate)
    request = suggestion.requests.create_or_find_by!(seller: seller)
    notify_late_request(suggestion, request)

    outcome =
      if suggestion.previously_new_record? then :created
      elsif request.previously_new_record? then :joined
      else :already_requested
      end
    Result.new(outcome: outcome, suggestion: suggestion, category: nil)
  end

  # Qualquer categoria, ativa ou não, cujo slug ou nome dê a mesma chave. O
  # slug conta à parte porque renomear uma categoria mantém o slug antigo, e
  # ele é único na árvore inteira (aceitar o nome colidiria).
  def self.existing_category_for(key)
    Category::Tree.load.categories.find { |category| category.slug == key || normalize_key(category.name) == key }
  end

  # A pendente com a mesma chave, ou uma nova. `create_or_find_by!` cria num
  # savepoint e, se o índice único recusar (outro ateliê criou no mesmo
  # instante), lê a que venceu.
  def self.pending_for!(candidate)
    pending.create_or_find_by!(normalized_key: candidate.normalized_key) { |suggestion| suggestion.name = candidate.name }
  end
  private_class_method :pending_for!

  # O admin pode decidir entre a leitura da pendente e a criação do pedido:
  # o aviso dele já saiu sem este ateliê, então o pedido avisa por conta
  # própria. O job ignora o pedido já avisado, então não há e-mail em dobro.
  def self.notify_late_request(suggestion, request)
    return unless request.previously_new_record?
    # Consulta à parte, sem `reload`: recarregar zera o `previously_new_record?`
    # que o `suggest!` usa para dizer se a sugestão foi criada agora.
    return if pending.exists?(suggestion.id)

    NotifyCategorySuggestionDecisionJob.perform_later(request)
  end
  private_class_method :notify_late_request

  # Cria a categoria e encerra a sugestão numa transação só, com a linha
  # travada: dois cliques (ou dois admins) não criam nada em dobro nem mandam
  # e-mail em dobro. Devolve false se a sugestão já estava decidida ou se a
  # categoria não pôde ser criada (o motivo fica em `errors`).
  def accept!(name:, parent:, admin:)
    accepted = with_lock do
      next false unless pending?

      if parent && !parent.visible?
        errors.add(:base, "A categoria-mãe \"#{parent.breadcrumb_name}\" está fora da loja: a categoria nova também ficaria escondida.")
        next false
      end

      category = Category.new(name: name.to_s.squish, parent: parent)
      unless category.save
        add_category_errors(category)
        raise ActiveRecord::Rollback
      end

      update!(status: :accepted, category: category, decided_by_user: admin, decided_at: Time.current)
      true
    end

    notify_requesters if accepted
    accepted.present?
  end

  def reject!(admin:)
    rejected = with_lock do
      next false unless pending?

      update!(status: :rejected, decided_by_user: admin, decided_at: Time.current)
    end

    notify_requesters if rejected
    rejected.present?
  end

  private

  # Um job por ateliê, enfileirado depois do commit (fora do `with_lock`):
  # um retry repete só aquele e-mail, e um rollback não deixa e-mail no ar.
  def notify_requesters
    requests.where(notified_at: nil).find_each { |request| NotifyCategorySuggestionDecisionJob.perform_later(request) }
  end

  def add_category_errors(category)
    if category.errors.of_kind?(:slug, :taken) && (existing = Category.find_by(slug: category.slug))
      errors.add(:base, "Já existe uma categoria com esse nome: #{existing.breadcrumb_name}.")
    else
      category.errors.full_messages.each { |message| errors.add(:base, message) }
    end
  end

  def normalize_name
    self.name = name.to_s.squish
    self.normalized_key = self.class.normalize_key(name)
  end

  def name_has_letters_or_digits
    errors.add(:name, "precisa ter letras ou números") if name.present? && normalized_key.blank?
    errors.add(:name, "é longo demais") if normalized_key.length > KEY_MAX_LENGTH
  end
end
