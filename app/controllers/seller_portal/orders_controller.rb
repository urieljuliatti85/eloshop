module SellerPortal
  class OrdersController < BaseController
    def index
      @seller_orders = current_seller.seller_orders.includes(:shipment, order: :customer).order(created_at: :desc)
    end

    def show
      @seller_order = seller_order_scope.find_by!(order_id: params[:id])
      @order = @seller_order.order
      @order_items = @seller_order.order_items
    end

    def ship
      shipment = current_seller.seller_orders.find_by!(order_id: params[:id]).shipment
      raise ActiveRecord::RecordNotFound unless shipment

      shipment.mark_shipped!

      message = shipment.local_pickup? ? "Pedido marcado como pronto para retirada." : "Pedido marcado como enviado."
      redirect_to seller_order_path(shipment.order), notice: message
    rescue Shipment::InvalidStatusTransition => e
      redirect_to seller_order_path(params[:id]), alert: e.message
    end

    def deliver
      shipment = current_seller.seller_orders.find_by!(order_id: params[:id]).shipment
      raise ActiveRecord::RecordNotFound unless shipment

      shipment.mark_delivered!

      message = shipment.local_pickup? ? "Retirada confirmada." : "Entrega confirmada."
      redirect_to seller_order_path(shipment.order), notice: message
    rescue Shipment::InvalidStatusTransition => e
      redirect_to seller_order_path(params[:id]), alert: e.message
    end

    def cancel
      order = current_seller.seller_orders.find_by!(order_id: params[:id]).order
      Orders::Cancel.new.call(order)

      redirect_to seller_order_path(order), notice: "Pedido cancelado e estoque devolvido."
    rescue Orders::Cancel::InvalidCancellation => e
      redirect_to seller_order_path(order), alert: e.message
    end

    private

    def seller_order_scope
      current_seller.seller_orders.includes(:shipment, order: :customer, order_items: :product)
    end
  end
end
