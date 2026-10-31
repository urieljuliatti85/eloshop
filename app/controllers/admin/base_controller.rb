module Admin
  class BaseController < ApplicationController
    include Paginatable

    layout "admin"

    before_action :require_admin!
    # Depois do login: o `before_action` padrão do PaperTrail roda antes de a sessão ser retomada.
    before_action :set_paper_trail_whodunnit

    private

    # Checagem central de autorização do admin — nunca espalhar
    # `if current_user.admin?` pelos controllers (ver CLAUDE.md §38).
    def require_admin!
      redirect_to new_session_path unless Current.user&.admin?
    end
  end
end
