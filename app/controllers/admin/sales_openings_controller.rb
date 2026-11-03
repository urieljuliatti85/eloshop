module Admin
  # Encerra o pré-cadastro. É uma ação só de ida: a data da abertura marca o
  # início da comissão de lançamento de quem já estava aprovado.
  class SalesOpeningsController < BaseController
    def create
      if PlatformSetting.open_sales!
        AnnounceSalesOpeningJob.perform_later
        redirect_to admin_root_path, notice: "Vendas abertas. Os ateliês aprovados e os da vitrine vão receber o aviso por e-mail."
      else
        redirect_to admin_root_path, alert: "As vendas já estavam abertas."
      end
    end
  end
end
