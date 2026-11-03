# Configuração global da plataforma, em uma linha só (o banco garante `id = 1`).
class PlatformSetting < ApplicationRecord
  SINGLETON_ID = 1

  # Aviso ao artesão durante o pré-cadastro, no painel e no e-mail de
  # aprovação: "pronta" quando todos os primeiros passos estão feitos
  # (`Seller#setup_steps`). A data é promessa do negócio — mude aqui se mudar.
  SALES_OPENING_PROMISE = "As vendas abrem em breve e avisaremos por e-mail.".freeze
  PRE_LAUNCH_READY_NOTICE = "Sua loja está pronta. #{SALES_OPENING_PROMISE}".freeze
  PRE_LAUNCH_INCOMPLETE_NOTICE = "Sua loja está quase pronta, siga os passos, integre com o Mercado Pago e adicione produtos. #{SALES_OPENING_PROMISE}".freeze

  def self.pre_launch_notice(ready:)
    ready ? PRE_LAUNCH_READY_NOTICE : PRE_LAUNCH_INCOMPLETE_NOTICE
  end

  def self.instance
    find_or_create_by!(id: SINGLETON_ID)
  rescue ActiveRecord::RecordNotUnique
    find(SINGLETON_ID)
  end

  # Única resposta para "a loja já vende?". Com as vendas fechadas o catálogo,
  # o cadastro e o painel funcionam; carrinho, checkout e pagamento recusam.
  def self.sales_open?
    sales_opened_at.present?
  end

  def self.sales_opened_at
    find_by(id: SINGLETON_ID)&.sales_opened_at
  end

  # Abre uma vez só: a data marca o início da comissão de lançamento de quem
  # já estava aprovado, então reabrir a moveria. Devolve false se já estava
  # aberta, para quem chama não repetir o aviso aos vendedores.
  def self.open_sales!
    setting = instance
    setting.with_lock do
      return false if setting.sales_opened_at.present?

      setting.update!(sales_opened_at: Time.current)
    end
    true
  end
end
