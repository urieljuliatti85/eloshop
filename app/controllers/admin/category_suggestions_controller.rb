module Admin
  # Categorias que os ateliês sugeriram no cadastro do produto. Aceitar cria
  # a categoria sob a mãe escolhida (com o nome corrigido, se for o caso);
  # recusar só encerra. As duas avisam por e-mail todos os que sugeriram.
  class CategorySuggestionsController < BaseController
    before_action :set_suggestion, only: %i[accept reject]

    def index
      @suggestions = paginate(
        CategorySuggestion
          .in_order_of(:status, %w[pending accepted rejected])
          .order(created_at: :desc)
          .preload(:category, requests: { seller: :users })
      )
      @category_tree = Category::Tree.load
    end

    def accept
      parent_id = accept_params[:parent_id].presence
      parent = parent_id && Category.find(parent_id)

      if @suggestion.accept!(name: accept_params[:name], parent: parent, admin: Current.user)
        redirect_to admin_category_suggestions_path, notice: "Categoria \"#{@suggestion.category.breadcrumb_name}\" criada. Os ateliês que sugeriram vão receber o aviso por e-mail."
      else
        redirect_to admin_category_suggestions_path, alert: decision_error
      end
    end

    def reject
      if @suggestion.reject!(admin: Current.user)
        redirect_to admin_category_suggestions_path, notice: "Sugestão recusada. Os ateliês que sugeriram vão receber o aviso por e-mail."
      else
        redirect_to admin_category_suggestions_path, alert: decision_error
      end
    end

    private

    def set_suggestion
      @suggestion = CategorySuggestion.find(params[:id])
    end

    def accept_params
      params.expect(category_suggestion: %i[name parent_id])
    end

    def decision_error
      @suggestion.errors.full_messages.to_sentence.presence || "Esta sugestão já tinha sido decidida."
    end
  end
end
