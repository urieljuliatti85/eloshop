module SellerPortal
  class NotificationsController < BaseController
    def index
      @notifications = current_seller.notifications.chronological
    end

    def mark_as_read
      notification = current_seller.notifications.find(params[:id])
      notification.mark_as_read!

      redirect_to (notification.url.presence || seller_notifications_path)
    end
  end
end
