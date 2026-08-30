module Admin
  class CustomersController < BaseController
    def index
      @customers = Customer.order(created_at: :desc)
      @customers = @customers.where("name ILIKE :term OR email ILIKE :term", term: "%#{params[:query]}%") if params[:query].present?
    end

    def show
      @customer = Customer.find(params[:id])
      @orders = @customer.orders.order(created_at: :desc)
    end
  end
end
