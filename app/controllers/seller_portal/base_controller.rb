module SellerPortal
  class BaseController < ApplicationController
    layout "seller"

    before_action :require_seller!

    helper_method :current_seller

    private

    def current_seller
      Current.user.seller
    end

    def require_seller!
      redirect_to new_session_path unless Current.user&.seller?
    end
  end
end
