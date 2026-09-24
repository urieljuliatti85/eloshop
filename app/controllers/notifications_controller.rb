class NotificationsController < StorefrontController
  def index
    @notifications = Current.customer.notifications.chronological
  end

  def mark_as_read
    notification = Current.customer.notifications.find(params[:id])
    notification.mark_as_read!

    redirect_to (notification.url.presence || notifications_path)
  end
end
