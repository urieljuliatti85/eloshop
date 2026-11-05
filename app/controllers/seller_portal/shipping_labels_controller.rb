module SellerPortal
  # Etiqueta da SuperFrete pelo painel (ADR 005, "Etapa 2 e 3"). Tudo parte de
  # `current_seller`: o pedido de outro ateliê responde 404.
  class ShippingLabelsController < BaseController
    PACKAGE_FIELDS = %i[height_cm width_cm length_cm weight_grams].freeze

    rate_limit to: 20, within: 10.minutes, only: %i[create destroy], by: -> { current_seller.id },
      with: -> { redirect_to seller_order_path(params[:order_id]), alert: "Muitas tentativas. Tente de novo em alguns minutos." }

    before_action :set_shipment

    # Escolha do pacote e do serviço. Com as medidas no formulário (GET), cota
    # na SuperFrete e mostra preço, prazo e as medidas finais — a SuperFrete
    # arredonda para o mínimo do serviço.
    def new
      @blocker = ShippingLabels::Guard.account_blocker(current_seller, @order) || ShippingLabels::Guard.blocker(@shipment)
      @package = requested_package.presence || suggested_package
      return if @blocker || requested_package.blank?

      @options = ShippingLabels.client_for(current_seller, interactive: true).quote(
        origin_zip_code: current_seller.origin_zip_code.to_s.gsub(/\D/, ""),
        destination_zip_code: @order.shipping_address_snapshot["zip_code"].to_s.gsub(/\D/, ""),
        **requested_package
      )
    rescue ShippingLabels::Client::Error => e
      @quote_error = "Não foi possível cotar a etiqueta: #{e.message}"
    end

    def create
      ShippingLabels::Request.new(shipment: @shipment, service_code: params[:service_code], **PACKAGE_FIELDS.index_with { nil }, **requested_package).call
      redirect_to seller_order_path(@order), notice: "Estamos gerando a etiqueta na SuperFrete. Em instantes ela aparece aqui."
    rescue ShippingLabels::Refused => e
      redirect_to new_seller_order_shipping_label_path(@order, **requested_package), alert: e.message
    end

    def destroy
      ShippingLabels::Cancel.new(active_label!, client: ShippingLabels.client_for(current_seller, interactive: true)).call
      redirect_to seller_order_path(@order), notice: "Etiqueta cancelada. O valor volta para a sua carteira na SuperFrete."
    rescue ShippingLabels::Refused => e
      redirect_to seller_order_path(@order), alert: e.message
    end

    # O link do PDF muda a cada consulta e não é guardado: pedido na hora.
    def print
      label = active_label!
      raise ActiveRecord::RecordNotFound unless label.purchased?

      url = ShippingLabels.client_for(current_seller, interactive: true).order_info(label.provider_order_id).print_url
      unless url.present? && URI.parse(url).is_a?(URI::HTTPS)
        return redirect_to(seller_order_path(@order), alert: "A SuperFrete não devolveu o PDF da etiqueta. Tente de novo em instantes.")
      end

      redirect_to url, allow_other_host: true
    rescue ShippingLabels::Client::Error, URI::InvalidURIError
      redirect_to seller_order_path(@order), alert: "Não foi possível abrir a etiqueta agora. Tente de novo em instantes."
    end

    # Pagamento sem confirmação: confere de novo na SuperFrete. Nunca reenvia
    # o pagamento (ShippingLabels::Purchase).
    def reconcile
      label = active_label!
      PurchaseShippingLabelJob.perform_later(label) if label.in_progress?
      redirect_to seller_order_path(@order), notice: "Conferindo a etiqueta com a SuperFrete."
    end

    private

    def set_shipment
      seller_order = current_seller.seller_orders.find_by!(order_id: params[:order_id])
      @order = seller_order.order
      @shipment = seller_order.shipment
      raise ActiveRecord::RecordNotFound if @shipment.nil? || @shipment.local_pickup?
    end

    def active_label!
      @shipment.shipping_labels.active.first!
    end

    # Só as quatro medidas, como inteiros; o que não for número fica de fora.
    def requested_package
      @requested_package ||= params.permit(*PACKAGE_FIELDS).to_h.symbolize_keys
        .transform_values { |value| Integer(value, exception: false) }.compact
    end

    # Uma peça: as medidas dela. Mais de uma: as maiores medidas e a soma dos
    # pesos — ponto de partida, o ateliê corrige para a caixa real.
    def suggested_package
      products = @shipment.seller_order.order_items.includes(:product).flat_map { |item| [ item.product ] * item.quantity }.compact
      return {} if products.empty?

      {
        height_cm: products.map { |product| product.height_cm.to_i }.max,
        width_cm: products.map { |product| product.width_cm.to_i }.max,
        length_cm: products.map { |product| product.length_cm.to_i }.max,
        weight_grams: products.sum { |product| product.weight_grams.to_i }
      }.select { |_field, value| value.positive? }
    end
  end
end
