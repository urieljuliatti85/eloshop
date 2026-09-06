module SellerPortal
  class PostalCodesController < BaseController
    def show
      address = PostalCodeLookup.new.call(params[:cep])

      if address
        render json: address.to_h
      else
        render json: {}, status: :not_found
      end
    end
  end
end
