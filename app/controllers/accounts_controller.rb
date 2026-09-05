# Página inicial da área do cliente: reúne os destinos da conta e um resumo
# do que existe em cada um.
class AccountsController < StorefrontController
  def show
    @customer = Current.customer
    @recent_orders = @customer.orders.includes(:order_items).order(created_at: :desc).limit(3)
    @orders_count = @customer.orders.count
    @addresses_count = @customer.addresses.count
  end
end
