class CreditsController < StorefrontController
  allow_unauthenticated_customer_access

  def show
    @image_credits = ImageCredit.all
  end
end
