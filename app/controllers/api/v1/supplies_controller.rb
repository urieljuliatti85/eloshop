module Api
  module V1
    class SuppliesController < BaseController
      PER_PAGE = 12

      before_action :validate_listing_params, only: :index

      def index
        scope = Product.supply_visible
        @page = requested_page || 1
        @total_count = scope.count
        @total_pages = (@total_count / PER_PAGE.to_f).ceil
        return @products = Product.none if @page > @total_pages

        @products = scope.preload(:seller, :price_tiers, :product_variants)
          .order(created_at: :desc).limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
      end

      def show
        seller = Seller.supply_listed.find_by!(slug: params[:seller_slug])
        @product = seller.products.supply_visible.preload(:price_tiers, :product_variants).find_by!(slug: params[:slug])
      end

      private

      def validate_listing_params
        invalid = :page if params.key?(:page) && requested_page.nil?
        render_invalid_parameter(invalid.to_s) if invalid
      end

      def requested_page
        return unless params[:page].is_a?(String)

        page = Integer(params[:page], 10, exception: false)
        page if page&.positive?
      end
    end
  end
end
