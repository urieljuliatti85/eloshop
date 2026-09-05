# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#format_price" do
    it "formats cents as brazilian currency" do
      expect(helper.format_price(8_990)).to eq("R$ 89,90")
      expect(helper.format_price(15_900)).to eq("R$ 159,00")
    end

    it "formats values below one real" do
      expect(helper.format_price(10)).to eq("R$ 0,10")
      expect(helper.format_price(1)).to eq("R$ 0,01")
    end

    it "formats zero as a real value, not as absent" do
      expect(helper.format_price(0)).to eq("R$ 0,00")
    end

    # Frete não calculado e subtotal mínimo de cupom são opcionais: "R$ 0,00"
    # afirmaria um valor que ninguém decidiu.
    it "renders a dash for a missing value" do
      expect(helper.format_price(nil)).to eq("—")
      expect(helper.format_price(nil, blank: "grátis")).to eq("grátis")
    end

    # A divisão por Rational, e não por Float, é a razão de o helper existir.
    it "converts large values without floating point drift" do
      expect(helper.format_price(999_999_999)).to eq("R$ 9.999.999,99")
    end
  end
end
