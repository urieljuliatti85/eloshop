# Decisão sobre a categoria que o ateliê sugeriu no cadastro do produto.
class CategorySuggestionMailer < ApplicationMailer
  # A categoria já está na lista; o produto não muda sozinho (decisão de
  # 2026-11-04), então o e-mail convida o ateliê a escolhê-la.
  def accepted(request, recipient)
    @seller = request.seller
    @suggestion = request.category_suggestion
    @category_path = @suggestion.category.breadcrumb_name

    mail(to: recipient, subject: "A categoria \"#{@suggestion.category.name}\" já está disponível na EloShop")
  end

  def rejected(request, recipient)
    @seller = request.seller
    @suggestion = request.category_suggestion

    mail(to: recipient, subject: "Sobre a categoria \"#{@suggestion.name}\" que você sugeriu")
  end
end
