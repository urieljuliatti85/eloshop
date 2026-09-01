class ApplicationController < ActionController::Base
  include Authentication
  before_action :set_observability_context
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def set_observability_context
    Rails.event.set_context(
      request_id: request.request_id,
      http_method: request.request_method
    )
  end
end
