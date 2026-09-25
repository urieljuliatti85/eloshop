module Admin
  class NotificationsController < BaseController
    def index
      @notifications = Current.user.notifications.chronological
    end

    def mark_as_read
      notification = Current.user.notifications.find(params[:id])
      notification.mark_as_read!

      redirect_to (notification.url.presence || admin_notifications_path)
    end
  end
end
