module SellerPortal
  # O ateliê sugere uma categoria que não achou na lista, a partir do cadastro
  # do produto. O envio é separado do formulário do produto (formulário irmão,
  # ligado ao campo pelo atributo `form=`): não leva os campos nem as fotos do
  # produto, não passa pela validação dele e não depende de ele salvar.
  class CategorySuggestionsController < BaseController
    rate_limit to: 5, within: 1.hour, only: :create, by: -> { current_seller.id }, name: "per-seller",
      with: -> { respond_with_field(message: "Muitas sugestões em pouco tempo. Tente de novo mais tarde.", tone: :error, status: :too_many_requests) }

    def create
      name = params.expect(category_suggestion: [ :name ])[:name]
      result = CategorySuggestion.suggest!(seller: current_seller, name: name)

      case result.outcome
      when :created, :joined
        respond_with_field(message: "Recebemos a sugestão \"#{result.suggestion.name}\". Vamos analisar e avisar você por e-mail.", tone: :success)
      when :already_requested
        respond_with_field(message: "Você já sugeriu \"#{result.suggestion.name}\". Avisaremos por e-mail quando analisarmos.", tone: :success)
      when :category_exists
        respond_with_field(message: "A categoria \"#{result.category.breadcrumb_name}\" já existe: escolha-a na lista acima.", tone: :info)
      else
        respond_with_field(message: result.suggestion.errors.full_messages.to_sentence, tone: :error, value: name, status: :unprocessable_entity)
      end
    end

    private

    def respond_with_field(message:, tone:, value: nil, status: :ok)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "category-suggestion",
            partial: "seller_portal/category_suggestions/field",
            locals: { message: message, tone: tone, value: value }
          ), status: status
        end
        format.html do
          flash_type = tone == :error ? :alert : :notice
          redirect_back_or_to seller_products_path, flash_type => message
        end
      end
    end
  end
end
