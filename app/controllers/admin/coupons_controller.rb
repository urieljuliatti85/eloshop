module Admin
  class CouponsController < BaseController
    before_action :set_coupon, only: %i[edit update destroy]

    def index
      @coupons = Coupon.order(created_at: :desc)
    end

    def new
      @coupon = Coupon.new(discount_type: "percentage", active: true)
    end

    def create
      @coupon = Coupon.new(coupon_params)

      if @coupon.save
        redirect_to admin_coupons_path, notice: "Cupom criado com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @coupon.update(coupon_params)
        redirect_to admin_coupons_path, notice: "Cupom atualizado com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @coupon.destroy
      redirect_to admin_coupons_path, notice: "Cupom removido."
    end

    private

    def set_coupon
      @coupon = Coupon.find(params[:id])
    end

    def coupon_params
      params.expect(coupon: %i[code discount_type percentage amount_cents minimum_subtotal_cents max_uses starts_at expires_at active])
    end
  end
end
