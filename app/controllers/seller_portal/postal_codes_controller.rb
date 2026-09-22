module SellerPortal
  class PostalCodesController < BaseController
    rate_limit to: 30, within: 1.minute, with: -> { head :too_many_requests }

    def show
      address = PostalCodeLookup.new.call(params[:cep])

      if address
        render json: address.to_h
      else
        render json: {}, status: :not_found
      end
    end

    def index
      suggestions = PostalCodeLookup.new.search(
        state: params[:state],
        city: params[:city],
        street: params[:street]
      )

      render json: suggestions.map(&:to_h)
    end
  end
end
