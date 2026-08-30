module CustomerAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :require_customer_authentication
    helper_method :customer_authenticated?
  end

  class_methods do
    def allow_unauthenticated_customer_access(**options)
      skip_before_action :require_customer_authentication, **options
    end
  end

  private
    def customer_authenticated?
      resume_customer_session
    end

    def require_customer_authentication
      resume_customer_session || request_customer_authentication
    end

    def resume_customer_session
      Current.customer_session ||= find_customer_session_by_cookie
    end

    # Ver comentário equivalente em Authentication#find_session_by_cookie.
    def find_customer_session_by_cookie
      return unless cookies.signed[:customer_session_id]

      CustomerSession.active.find_by(id: cookies.signed[:customer_session_id])&.tap(&:touch)
    end

    def request_customer_authentication
      redirect_to new_customer_session_path
    end

    def start_new_customer_session_for(customer)
      customer.customer_sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |customer_session|
        Current.customer_session = customer_session
        cookies.signed.permanent[:customer_session_id] = { value: customer_session.id, httponly: true, same_site: :lax, secure: Rails.env.production? }
      end
    end

    def terminate_customer_session
      Current.customer_session.destroy
      cookies.delete(:customer_session_id)
    end

    def associate_cart_with_customer(customer)
      Current.cart.update!(customer: customer)
    end
end
