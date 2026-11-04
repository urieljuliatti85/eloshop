# Um ateliê que pediu uma CategorySuggestion. Único por sugestão e ateliê
# (índice no banco); `notified_at` marca que a decisão já chegou por e-mail.
class CategorySuggestionRequest < ApplicationRecord
  belongs_to :category_suggestion, inverse_of: :requests
  belongs_to :seller
end
