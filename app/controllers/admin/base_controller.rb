module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :require_admin!

    private

    # Checagem central de autorização do admin — nunca espalhar
    # `if current_user.admin?` pelos controllers (ver CLAUDE.md §38).
    def require_admin!
      redirect_to new_session_path unless Current.user&.admin?
    end
  end
end
