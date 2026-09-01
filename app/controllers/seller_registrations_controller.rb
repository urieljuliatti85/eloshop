class SellerRegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 15.minutes, only: :create,
    with: -> { redirect_to new_seller_registration_path, alert: "Tente novamente mais tarde." }

  def new
    @seller = Seller.new
    @user = User.new(role: :seller)
  end

  def create
    @seller = Seller.new(seller_params)
    @user = User.new(user_params.merge(role: :seller, seller: @seller))

    if @seller.valid? && @user.valid?
      Seller.transaction do
        @seller.save!
        @user.save!
      end
      start_new_session_for(@user)
      redirect_to seller_root_path, notice: "Cadastro recebido. A publicação será liberada após a aprovação da plataforma."
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @user.errors.add(:email_address, "já está em uso")
    render :new, status: :unprocessable_entity
  end

  private

  def seller_params
    params.expect(seller: [ :name ])
  end

  def user_params
    params.expect(user: %i[email_address password password_confirmation])
  end
end
