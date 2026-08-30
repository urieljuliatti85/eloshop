module Carting
  extend ActiveSupport::Concern

  included do
    before_action :set_current_cart
  end

  private

  def set_current_cart
    Current.cart = find_cart_by_cookie || create_cart_with_cookie
  end

  def find_cart_by_cookie
    Cart.find_by(session_token: cookies.signed[:cart_token]) if cookies.signed[:cart_token]
  end

  def create_cart_with_cookie
    Cart.create!(session_token: SecureRandom.hex(20)).tap do |cart|
      cookies.signed.permanent[:cart_token] = { value: cart.session_token, httponly: true, same_site: :lax, secure: Rails.env.production? }
    end
  end
end
